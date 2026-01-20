#!/usr/bin/env node
/**
 * Plasm WASI Runner
 * 
 * A command-line tool to run Plasm WebAssembly modules with WASI support
 * and full standard library bindings.
 * 
 * Usage: node wasi_runner.js <module.wasm> [args...]
 */

const fs = require('fs');
const { WASI } = require('wasi');

class PlasmWASIRunner {
  constructor() {
    this.memory = null;
    this.textEncoder = new TextEncoder();
    this.textDecoder = new TextDecoder();
    this.mapStorage = new Map();
    this.nextMapId = 1;
  }

  /**
   * Read a string from WebAssembly memory
   */
  readString(ptr) {
    if (!this.memory || ptr === 0) return '';
    
    const view = new DataView(this.memory.buffer);
    
    // Read length (first 4 bytes)
    const length = view.getUint32(ptr, true);
    
    // Read string bytes
    const bytes = new Uint8Array(this.memory.buffer, ptr + 4, length);
    return this.textDecoder.decode(bytes);
  }

  /**
   * Read an i64 value from memory
   */
  readI64(ptr) {
    if (!this.memory) return 0;
    const view = new DataView(this.memory.buffer);
    return Number(view.getBigInt64(ptr, true));
  }

  /**
   * Read a value with type checking
   */
  readValue(ptr) {
    if (!this.memory || ptr === 0) return ptr;
    
    const view = new DataView(this.memory.buffer);
    
    // Check type tag (simplified)
    // In full implementation, read tag and dispatch
    try {
      // Try string first
      return this.readString(ptr);
    } catch {
      // Fall back to number
      try {
        return this.readI64(ptr);
      } catch {
        return ptr;
      }
    }
  }

  /**
   * Create stdlib bindings for WASI environment
   */
  createBindings() {
    return {
      // I/O bindings
      __external_println: (ptr) => {
        const value = this.readValue(ptr);
        console.log(value);
      },
      
      __external_print: (ptr) => {
        const value = this.readValue(ptr);
        process.stdout.write(String(value));
      },
      
      __external_readLine: () => {
        // Synchronous stdin reading would require additional setup
        // For now, return empty
        return 0;
      },

      // Map bindings
      __external_map_init: () => {
        const mapId = this.nextMapId++;
        this.mapStorage.set(mapId, new Map());
        return mapId;
      },

      __external_map_put: (mapId, keyPtr, valuePtr) => {
        if (!this.mapStorage.has(mapId)) {
          this.mapStorage.set(mapId, new Map());
        }
        const key = this.readValue(keyPtr);
        const value = this.readValue(valuePtr);
        this.mapStorage.get(mapId).set(key, value);
      },
      
      __external_map_get: (mapId, keyPtr, resultPtr) => {
        const map = this.mapStorage.get(mapId);
        if (!map) {
          // Write (0, false) to result
          const view = new DataView(this.memory.buffer);
          view.setBigInt64(resultPtr, 0n, true);
          view.setUint8(resultPtr + 8, 0);
          return;
        }
        
        const key = this.readValue(keyPtr);
        const exists = map.has(key);
        const value = exists ? map.get(key) : 0;
        
        // Write (value, exists) to result
        const view = new DataView(this.memory.buffer);
        if (typeof value === 'number') {
          view.setBigInt64(resultPtr, BigInt(value), true);
        }
        view.setUint8(resultPtr + 8, exists ? 1 : 0);
      },
      
      __external_map_remove: (mapId, keyPtr) => {
        const map = this.mapStorage.get(mapId);
        if (map) {
          const key = this.readValue(keyPtr);
          map.delete(key);
        }
      },
      
      __external_map_size: (mapId) => {
        const map = this.mapStorage.get(mapId);
        return map ? map.size : 0;
      },
      
      __external_map_clear: (mapId) => {
        const map = this.mapStorage.get(mapId);
        if (map) {
          map.clear();
        }
      }
    };
  }

  /**
   * Run a WASM module with WASI support
   */
  async run(wasmPath, args = []) {
    // Read WASM file
    const wasmBytes = fs.readFileSync(wasmPath);

    // Create WASI instance
    const wasi = new WASI({
      args: [wasmPath, ...args],
      env: process.env,
      preopens: {
        '/': process.cwd()
      }
    });

    // Create import object with WASI and stdlib bindings
    const importObject = {
      wasi_snapshot_preview1: wasi.wasiImport,
      env: this.createBindings()
    };

    // Instantiate module
    const { instance } = await WebAssembly.instantiate(wasmBytes, importObject);
    
    // Store memory reference
    this.memory = instance.exports.memory;

    // Start WASI
    try {
      wasi.start(instance);
    } catch (e) {
      if (e.code !== 0) {
        console.error(`Process exited with code ${e.code}`);
        process.exit(e.code);
      }
    }
  }
}

// Main entry point
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error('Usage: node wasi_runner.js <module.wasm> [args...]');
    process.exit(1);
  }

  const wasmPath = args[0];
  const moduleArgs = args.slice(1);

  const runner = new PlasmWASIRunner();
  runner.run(wasmPath, moduleArgs).catch(err => {
    console.error('Error running module:', err);
    process.exit(1);
  });
}

module.exports = PlasmWASIRunner;
