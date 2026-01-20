/**
 * Plasm Standard Library - JavaScript Bindings
 * 
 * This module provides the runtime support for Plasm WebAssembly modules
 * in browser and Node.js environments. It handles:
 * - Loading and instantiating WASM modules
 * - Providing standard library implementations (io, map)
 * - Memory management for string handling
 * - Bridge between JavaScript and WebAssembly
 */

class PlasmRuntime {
  constructor() {
    this.memory = null;
    this.instance = null;
    this.textEncoder = new TextEncoder();
    this.textDecoder = new TextDecoder();
    this.mapStorage = new Map(); // For Map<K,V> implementation
    this.nextMapId = 1;
  }

  /**
   * Load and instantiate a Plasm WebAssembly module
   * @param {string|URL|ArrayBuffer} source - Path to .wasm file or ArrayBuffer
   * @param {Object} additionalImports - Additional import objects
   * @returns {Promise<WebAssembly.Instance>} The instantiated module
   */
  async loadModule(source, additionalImports = {}) {
    let wasmBytes;
    
    if (source instanceof ArrayBuffer) {
      wasmBytes = source;
    } else if (typeof source === 'string' || source instanceof URL) {
      const response = await fetch(source);
      wasmBytes = await response.arrayBuffer();
    } else {
      throw new Error('Invalid source type. Expected string, URL, or ArrayBuffer');
    }

    const importObject = {
      ...additionalImports,
      env: {
        ...this._createStdlibBindings(),
        ...(additionalImports.env || {})
      }
    };

    const result = await WebAssembly.instantiate(wasmBytes, importObject);
    this.instance = result.instance;
    this.memory = this.instance.exports.memory;

    return this.instance;
  }

  /**
   * Create standard library bindings for WebAssembly imports
   * @private
   */
  _createStdlibBindings() {
    return {
      // I/O bindings
      __external_println: (valuePtr) => {
        const value = this._readValue(valuePtr);
        console.log(value);
      },
      
      __external_print: (valuePtr) => {
        const value = this._readValue(valuePtr);
        process?.stdout?.write?.(String(value)) || console.log(value);
      },
      
      __external_readLine: () => {
        // In browser, this could use prompt() or an async input mechanism
        // For now, return a placeholder
        if (typeof prompt !== 'undefined') {
          return this._writeString(prompt() || '');
        }
        return 0;
      },

      // Map bindings
      __external_map_put: (mapId, keyPtr, valuePtr) => {
        if (!this.mapStorage.has(mapId)) {
          this.mapStorage.set(mapId, new Map());
        }
        const key = this._readValue(keyPtr);
        const value = this._readValue(valuePtr);
        this.mapStorage.get(mapId).set(key, value);
      },
      
      __external_map_get: (mapId, keyPtr) => {
        const map = this.mapStorage.get(mapId);
        if (!map) {
          return [0, 0]; // (defaultValue, false)
        }
        const key = this._readValue(keyPtr);
        const exists = map.has(key);
        const value = exists ? map.get(key) : 0;
        return [value, exists ? 1 : 0];
      },
      
      __external_map_remove: (mapId, keyPtr) => {
        const map = this.mapStorage.get(mapId);
        if (map) {
          const key = this._readValue(keyPtr);
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
      },
      
      __external_map_init: () => {
        const mapId = this.nextMapId++;
        this.mapStorage.set(mapId, new Map());
        return mapId;
      }
    };
  }

  /**
   * Read a value from WebAssembly memory
   * @private
   */
  _readValue(ptr) {
    if (!this.memory) return ptr;
    
    // For now, treat as i64/i32 value
    // In a full implementation, this would check the type tag
    const view = new DataView(this.memory.buffer);
    
    // Try to read as i64 first (if supported)
    if (ptr < this.memory.buffer.byteLength - 8) {
      try {
        return Number(view.getBigInt64(ptr, true));
      } catch {
        return view.getInt32(ptr, true);
      }
    }
    
    return ptr;
  }

  /**
   * Write a string to WebAssembly memory
   * @private
   */
  _writeString(str) {
    if (!this.memory) return 0;
    
    const bytes = this.textEncoder.encode(str);
    // Allocate space and write string
    // This is simplified; real implementation would use WASM allocator
    const ptr = 1024; // Fixed offset for now
    const view = new Uint8Array(this.memory.buffer);
    view.set(bytes, ptr);
    
    return ptr;
  }

  /**
   * Call an exported Plasm function
   * @param {string} name - Function name (without $ for procedures)
   * @param {...any} args - Function arguments
   * @returns {any} Return value
   */
  call(name, ...args) {
    if (!this.instance) {
      throw new Error('No module loaded. Call loadModule first.');
    }
    
    const funcName = name.startsWith('$') ? name : `$${name}`;
    const func = this.instance.exports[funcName];
    
    if (!func) {
      throw new Error(`Function ${funcName} not found in module exports`);
    }
    
    return func(...args);
  }

  /**
   * Get all exported functions from the loaded module
   * @returns {Object} Exported functions
   */
  getExports() {
    if (!this.instance) {
      throw new Error('No module loaded. Call loadModule first.');
    }
    return this.instance.exports;
  }
}

// Export for different environments
if (typeof module !== 'undefined' && module.exports) {
  // Node.js
  module.exports = PlasmRuntime;
} else if (typeof window !== 'undefined') {
  // Browser
  window.PlasmRuntime = PlasmRuntime;
}

// Also provide a convenient factory function
const createPlasmRuntime = () => new PlasmRuntime();

if (typeof module !== 'undefined' && module.exports) {
  module.exports.createPlasmRuntime = createPlasmRuntime;
} else if (typeof window !== 'undefined') {
  window.createPlasmRuntime = createPlasmRuntime;
}
