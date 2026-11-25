// Generated from scripts/check-changelog.ts by `npm run build`. Do not edit.
// Licenses of the bundled packages are in LICENSES.txt.
var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __getProtoOf = Object.getPrototypeOf;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __commonJS = (cb, mod) => function __require() {
  try {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  } catch (e) {
    throw mod = 0, e;
  }
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
  // If the importer is in node compatibility mode or this is not an ESM
  // file that has been converted to a CommonJS file using a Babel-
  // compatible transform (i.e. "__esModule" has not been set), then set
  // "default" to the CommonJS "module.exports" for node compatibility.
  isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
  mod
));

// node_modules/semver/internal/constants.js
var require_constants = __commonJS({
  "node_modules/semver/internal/constants.js"(exports, module) {
    "use strict";
    var SEMVER_SPEC_VERSION = "2.0.0";
    var MAX_LENGTH = 256;
    var MAX_SAFE_INTEGER = Number.MAX_SAFE_INTEGER || /* istanbul ignore next */
    9007199254740991;
    var MAX_SAFE_COMPONENT_LENGTH = 16;
    var MAX_SAFE_BUILD_LENGTH = MAX_LENGTH - 6;
    var WHITESPACE_CHARACTERS = [
      "	",
      "\n",
      "\v",
      "\f",
      "\r",
      " ",
      "\xA0",
      "\u1680",
      "\u2000",
      "\u2001",
      "\u2002",
      "\u2003",
      "\u2004",
      "\u2005",
      "\u2006",
      "\u2007",
      "\u2008",
      "\u2009",
      "\u200A",
      "\u2028",
      "\u2029",
      "\u202F",
      "\u205F",
      "\u3000",
      "\uFEFF"
    ];
    var RELEASE_TYPES = [
      "major",
      "premajor",
      "minor",
      "preminor",
      "patch",
      "prepatch",
      "prerelease"
    ];
    module.exports = {
      MAX_LENGTH,
      MAX_SAFE_COMPONENT_LENGTH,
      MAX_SAFE_BUILD_LENGTH,
      MAX_SAFE_INTEGER,
      WHITESPACE_CHARACTERS,
      RELEASE_TYPES,
      SEMVER_SPEC_VERSION,
      FLAG_INCLUDE_PRERELEASE: 1,
      FLAG_LOOSE: 2
    };
  }
});

// node_modules/semver/internal/debug.js
var require_debug = __commonJS({
  "node_modules/semver/internal/debug.js"(exports, module) {
    "use strict";
    var debug = typeof process === "object" && process.env && process.env.NODE_DEBUG && /\bsemver\b/i.test(process.env.NODE_DEBUG) ? (...args) => console.error("SEMVER", ...args) : () => {
    };
    module.exports = debug;
  }
});

// node_modules/semver/internal/re.js
var require_re = __commonJS({
  "node_modules/semver/internal/re.js"(exports, module) {
    "use strict";
    var {
      MAX_SAFE_COMPONENT_LENGTH,
      MAX_SAFE_BUILD_LENGTH,
      MAX_LENGTH
    } = require_constants();
    var debug = require_debug();
    exports = module.exports = {};
    var re = exports.re = [];
    var safeRe = exports.safeRe = [];
    var src = exports.src = [];
    var safeSrc = exports.safeSrc = [];
    var t = exports.t = {};
    var R = 0;
    var LETTERDASHNUMBER = "[a-zA-Z0-9-]";
    var safeRegexReplacements = [
      ["\\s", 1],
      ["\\d", MAX_LENGTH],
      [LETTERDASHNUMBER, MAX_SAFE_BUILD_LENGTH]
    ];
    var makeSafeRegex = (value) => {
      for (const [token, max] of safeRegexReplacements) {
        value = value.split(`${token}*`).join(`${token}{0,${max}}`).split(`${token}+`).join(`${token}{1,${max}}`);
      }
      return value;
    };
    var createToken = (name, value, isGlobal) => {
      const safe = makeSafeRegex(value);
      const index = R++;
      debug(name, index, value);
      t[name] = index;
      src[index] = value;
      safeSrc[index] = safe;
      re[index] = new RegExp(value, isGlobal ? "g" : void 0);
      safeRe[index] = new RegExp(safe, isGlobal ? "g" : void 0);
    };
    createToken("NUMERICIDENTIFIER", "0|[1-9]\\d*");
    createToken("NUMERICIDENTIFIERLOOSE", "\\d+");
    createToken("NONNUMERICIDENTIFIER", `\\d*[a-zA-Z-]${LETTERDASHNUMBER}*`);
    createToken("MAINVERSION", `(${src[t.NUMERICIDENTIFIER]})\\.(${src[t.NUMERICIDENTIFIER]})\\.(${src[t.NUMERICIDENTIFIER]})`);
    createToken("MAINVERSIONLOOSE", `(${src[t.NUMERICIDENTIFIERLOOSE]})\\.(${src[t.NUMERICIDENTIFIERLOOSE]})\\.(${src[t.NUMERICIDENTIFIERLOOSE]})`);
    createToken("PRERELEASEIDENTIFIER", `(?:${src[t.NONNUMERICIDENTIFIER]}|${src[t.NUMERICIDENTIFIER]})`);
    createToken("PRERELEASEIDENTIFIERLOOSE", `(?:${src[t.NONNUMERICIDENTIFIER]}|${src[t.NUMERICIDENTIFIERLOOSE]})`);
    createToken("PRERELEASE", `(?:-(${src[t.PRERELEASEIDENTIFIER]}(?:\\.${src[t.PRERELEASEIDENTIFIER]})*))`);
    createToken("PRERELEASELOOSE", `(?:-?(${src[t.PRERELEASEIDENTIFIERLOOSE]}(?:\\.${src[t.PRERELEASEIDENTIFIERLOOSE]})*))`);
    createToken("BUILDIDENTIFIER", `${LETTERDASHNUMBER}+`);
    createToken("BUILD", `(?:\\+(${src[t.BUILDIDENTIFIER]}(?:\\.${src[t.BUILDIDENTIFIER]})*))`);
    createToken("FULLPLAIN", `v?${src[t.MAINVERSION]}${src[t.PRERELEASE]}?${src[t.BUILD]}?`);
    createToken("FULL", `^${src[t.FULLPLAIN]}$`);
    createToken("LOOSEPLAIN", `[v=\\s]*${src[t.MAINVERSIONLOOSE]}${src[t.PRERELEASELOOSE]}?${src[t.BUILD]}?`);
    createToken("LOOSE", `^${src[t.LOOSEPLAIN]}$`);
    createToken("GTLT", "((?:<|>)?=?)");
    createToken("XRANGEIDENTIFIERLOOSE", `${src[t.NUMERICIDENTIFIERLOOSE]}|x|X|\\*`);
    createToken("XRANGEIDENTIFIER", `${src[t.NUMERICIDENTIFIER]}|x|X|\\*`);
    createToken("XRANGEPLAIN", `[v=\\s]*(${src[t.XRANGEIDENTIFIER]})(?:\\.(${src[t.XRANGEIDENTIFIER]})(?:\\.(${src[t.XRANGEIDENTIFIER]})(?:${src[t.PRERELEASE]})?${src[t.BUILD]}?)?)?`);
    createToken("XRANGEPLAINLOOSE", `[v=\\s]*(${src[t.XRANGEIDENTIFIERLOOSE]})(?:\\.(${src[t.XRANGEIDENTIFIERLOOSE]})(?:\\.(${src[t.XRANGEIDENTIFIERLOOSE]})(?:${src[t.PRERELEASELOOSE]})?${src[t.BUILD]}?)?)?`);
    createToken("XRANGE", `^${src[t.GTLT]}\\s*${src[t.XRANGEPLAIN]}$`);
    createToken("XRANGELOOSE", `^${src[t.GTLT]}\\s*${src[t.XRANGEPLAINLOOSE]}$`);
    createToken("COERCEPLAIN", `${"(^|[^\\d])(\\d{1,"}${MAX_SAFE_COMPONENT_LENGTH}})(?:\\.(\\d{1,${MAX_SAFE_COMPONENT_LENGTH}}))?(?:\\.(\\d{1,${MAX_SAFE_COMPONENT_LENGTH}}))?`);
    createToken("COERCE", `${src[t.COERCEPLAIN]}(?:$|[^\\d])`);
    createToken("COERCEFULL", src[t.COERCEPLAIN] + `(?:${src[t.PRERELEASE]})?(?:${src[t.BUILD]})?(?:$|[^\\d])`);
    createToken("COERCERTL", src[t.COERCE], true);
    createToken("COERCERTLFULL", src[t.COERCEFULL], true);
    createToken("LONETILDE", "(?:~>?)");
    createToken("TILDETRIM", `(\\s*)${src[t.LONETILDE]}\\s+`, true);
    exports.tildeTrimReplace = "$1~";
    createToken("TILDE", `^${src[t.LONETILDE]}${src[t.XRANGEPLAIN]}$`);
    createToken("TILDELOOSE", `^${src[t.LONETILDE]}${src[t.XRANGEPLAINLOOSE]}$`);
    createToken("LONECARET", "(?:\\^)");
    createToken("CARETTRIM", `(\\s*)${src[t.LONECARET]}\\s+`, true);
    exports.caretTrimReplace = "$1^";
    createToken("CARET", `^${src[t.LONECARET]}${src[t.XRANGEPLAIN]}$`);
    createToken("CARETLOOSE", `^${src[t.LONECARET]}${src[t.XRANGEPLAINLOOSE]}$`);
    createToken("COMPARATORLOOSE", `^${src[t.GTLT]}\\s*(${src[t.LOOSEPLAIN]})$|^$`);
    createToken("COMPARATOR", `^${src[t.GTLT]}\\s*(${src[t.FULLPLAIN]})$|^$`);
    createToken("COMPARATORTRIM", `(\\s*)${src[t.GTLT]}\\s*(${src[t.LOOSEPLAIN]}|${src[t.XRANGEPLAIN]})`, true);
    exports.comparatorTrimReplace = "$1$2$3";
    createToken("HYPHENRANGE", `^\\s*(${src[t.XRANGEPLAIN]})\\s+-\\s+(${src[t.XRANGEPLAIN]})\\s*$`);
    createToken("HYPHENRANGELOOSE", `^\\s*(${src[t.XRANGEPLAINLOOSE]})\\s+-\\s+(${src[t.XRANGEPLAINLOOSE]})\\s*$`);
    createToken("STAR", "(<|>)?=?\\s*\\*");
    createToken("GTE0", "^\\s*>=\\s*0\\.0\\.0\\s*$");
    createToken("GTE0PRE", "^\\s*>=\\s*0\\.0\\.0-0\\s*$");
  }
});

// node_modules/semver/internal/parse-options.js
var require_parse_options = __commonJS({
  "node_modules/semver/internal/parse-options.js"(exports, module) {
    "use strict";
    var looseOption = Object.freeze({ loose: true });
    var emptyOpts = Object.freeze({});
    var parseOptions = (options) => {
      if (!options) {
        return emptyOpts;
      }
      if (typeof options !== "object") {
        return looseOption;
      }
      return options;
    };
    module.exports = parseOptions;
  }
});

// node_modules/semver/internal/identifiers.js
var require_identifiers = __commonJS({
  "node_modules/semver/internal/identifiers.js"(exports, module) {
    "use strict";
    var numeric = /^[0-9]+$/;
    var compareIdentifiers = (a, b) => {
      if (typeof a === "number" && typeof b === "number") {
        return a === b ? 0 : a < b ? -1 : 1;
      }
      const anum = numeric.test(a);
      const bnum = numeric.test(b);
      if (anum && bnum) {
        a = +a;
        b = +b;
      }
      return a === b ? 0 : anum && !bnum ? -1 : bnum && !anum ? 1 : a < b ? -1 : 1;
    };
    var rcompareIdentifiers = (a, b) => compareIdentifiers(b, a);
    module.exports = {
      compareIdentifiers,
      rcompareIdentifiers
    };
  }
});

// node_modules/semver/classes/semver.js
var require_semver = __commonJS({
  "node_modules/semver/classes/semver.js"(exports, module) {
    "use strict";
    var debug = require_debug();
    var { MAX_LENGTH, MAX_SAFE_INTEGER } = require_constants();
    var { safeRe: re, t } = require_re();
    var parseOptions = require_parse_options();
    var { compareIdentifiers } = require_identifiers();
    var isPrereleaseIdentifier = (prerelease, identifier) => {
      const identifiers = identifier.split(".");
      if (identifiers.length > prerelease.length) {
        return false;
      }
      for (let i = 0; i < identifiers.length; i++) {
        if (compareIdentifiers(prerelease[i], identifiers[i]) !== 0) {
          return false;
        }
      }
      return true;
    };
    var SemVer = class _SemVer {
      constructor(version, options) {
        options = parseOptions(options);
        if (version instanceof _SemVer) {
          if (version.loose === !!options.loose && version.includePrerelease === !!options.includePrerelease) {
            return version;
          } else {
            version = version.version;
          }
        } else if (typeof version !== "string") {
          throw new TypeError(`Invalid version. Must be a string. Got type "${typeof version}".`);
        }
        if (version.length > MAX_LENGTH) {
          throw new TypeError(
            `version is longer than ${MAX_LENGTH} characters`
          );
        }
        debug("SemVer", version, options);
        this.options = options;
        this.loose = !!options.loose;
        this.includePrerelease = !!options.includePrerelease;
        const m = version.trim().match(options.loose ? re[t.LOOSE] : re[t.FULL]);
        if (!m) {
          throw new TypeError(`Invalid Version: ${version}`);
        }
        this.raw = version;
        this.major = +m[1];
        this.minor = +m[2];
        this.patch = +m[3];
        if (this.major > MAX_SAFE_INTEGER || this.major < 0) {
          throw new TypeError("Invalid major version");
        }
        if (this.minor > MAX_SAFE_INTEGER || this.minor < 0) {
          throw new TypeError("Invalid minor version");
        }
        if (this.patch > MAX_SAFE_INTEGER || this.patch < 0) {
          throw new TypeError("Invalid patch version");
        }
        if (!m[4]) {
          this.prerelease = [];
        } else {
          this.prerelease = m[4].split(".").map((id) => {
            if (/^[0-9]+$/.test(id)) {
              const num = +id;
              if (num >= 0 && num < MAX_SAFE_INTEGER) {
                return num;
              }
            }
            return id;
          });
        }
        this.build = m[5] ? m[5].split(".") : [];
        this.format();
      }
      format() {
        this.version = `${this.major}.${this.minor}.${this.patch}`;
        if (this.prerelease.length) {
          this.version += `-${this.prerelease.join(".")}`;
        }
        return this.version;
      }
      toString() {
        return this.version;
      }
      compare(other) {
        debug("SemVer.compare", this.version, this.options, other);
        if (!(other instanceof _SemVer)) {
          if (typeof other === "string" && other === this.version) {
            return 0;
          }
          other = new _SemVer(other, this.options);
        }
        if (other.version === this.version) {
          return 0;
        }
        return this.compareMain(other) || this.comparePre(other);
      }
      compareMain(other) {
        if (!(other instanceof _SemVer)) {
          other = new _SemVer(other, this.options);
        }
        if (this.major < other.major) {
          return -1;
        }
        if (this.major > other.major) {
          return 1;
        }
        if (this.minor < other.minor) {
          return -1;
        }
        if (this.minor > other.minor) {
          return 1;
        }
        if (this.patch < other.patch) {
          return -1;
        }
        if (this.patch > other.patch) {
          return 1;
        }
        return 0;
      }
      comparePre(other) {
        if (!(other instanceof _SemVer)) {
          other = new _SemVer(other, this.options);
        }
        if (this.prerelease.length && !other.prerelease.length) {
          return -1;
        } else if (!this.prerelease.length && other.prerelease.length) {
          return 1;
        } else if (!this.prerelease.length && !other.prerelease.length) {
          return 0;
        }
        let i = 0;
        do {
          const a = this.prerelease[i];
          const b = other.prerelease[i];
          debug("prerelease compare", i, a, b);
          if (a === void 0 && b === void 0) {
            return 0;
          } else if (b === void 0) {
            return 1;
          } else if (a === void 0) {
            return -1;
          } else if (a === b) {
            continue;
          } else {
            return compareIdentifiers(a, b);
          }
        } while (++i);
      }
      compareBuild(other) {
        if (!(other instanceof _SemVer)) {
          other = new _SemVer(other, this.options);
        }
        let i = 0;
        do {
          const a = this.build[i];
          const b = other.build[i];
          debug("build compare", i, a, b);
          if (a === void 0 && b === void 0) {
            return 0;
          } else if (b === void 0) {
            return 1;
          } else if (a === void 0) {
            return -1;
          } else if (a === b) {
            continue;
          } else {
            return compareIdentifiers(a, b);
          }
        } while (++i);
      }
      // preminor will bump the version up to the next minor release, and immediately
      // down to pre-release. premajor and prepatch work the same way.
      inc(release, identifier, identifierBase) {
        if (release.startsWith("pre")) {
          if (!identifier && identifierBase === false) {
            throw new Error("invalid increment argument: identifier is empty");
          }
          if (identifier) {
            const match = `-${identifier}`.match(this.options.loose ? re[t.PRERELEASELOOSE] : re[t.PRERELEASE]);
            if (!match || match[1] !== identifier) {
              throw new Error(`invalid identifier: ${identifier}`);
            }
          }
        }
        switch (release) {
          case "premajor":
            this.prerelease.length = 0;
            this.patch = 0;
            this.minor = 0;
            this.major++;
            this.inc("pre", identifier, identifierBase);
            break;
          case "preminor":
            this.prerelease.length = 0;
            this.patch = 0;
            this.minor++;
            this.inc("pre", identifier, identifierBase);
            break;
          case "prepatch":
            this.prerelease.length = 0;
            this.inc("patch", identifier, identifierBase);
            this.inc("pre", identifier, identifierBase);
            break;
          // If the input is a non-prerelease version, this acts the same as
          // prepatch.
          case "prerelease":
            if (this.prerelease.length === 0) {
              this.inc("patch", identifier, identifierBase);
            }
            this.inc("pre", identifier, identifierBase);
            break;
          case "release":
            if (this.prerelease.length === 0) {
              throw new Error(`version ${this.raw} is not a prerelease`);
            }
            this.prerelease.length = 0;
            break;
          case "major":
            if (this.minor !== 0 || this.patch !== 0 || this.prerelease.length === 0) {
              this.major++;
            }
            this.minor = 0;
            this.patch = 0;
            this.prerelease = [];
            break;
          case "minor":
            if (this.patch !== 0 || this.prerelease.length === 0) {
              this.minor++;
            }
            this.patch = 0;
            this.prerelease = [];
            break;
          case "patch":
            if (this.prerelease.length === 0) {
              this.patch++;
            }
            this.prerelease = [];
            break;
          // This probably shouldn't be used publicly.
          // 1.0.0 'pre' would become 1.0.0-0 which is the wrong direction.
          case "pre": {
            const base = Number(identifierBase) ? 1 : 0;
            if (this.prerelease.length === 0) {
              this.prerelease = [base];
            } else {
              let i = this.prerelease.length;
              while (--i >= 0) {
                if (typeof this.prerelease[i] === "number") {
                  this.prerelease[i]++;
                  i = -2;
                }
              }
              if (i === -1) {
                if (identifier === this.prerelease.join(".") && identifierBase === false) {
                  throw new Error("invalid increment argument: identifier already exists");
                }
                this.prerelease.push(base);
              }
            }
            if (identifier) {
              let prerelease = [identifier, base];
              if (identifierBase === false) {
                prerelease = [identifier];
              }
              if (isPrereleaseIdentifier(this.prerelease, identifier)) {
                const prereleaseBase = this.prerelease[identifier.split(".").length];
                if (isNaN(prereleaseBase)) {
                  this.prerelease = prerelease;
                }
              } else {
                this.prerelease = prerelease;
              }
            }
            break;
          }
          default:
            throw new Error(`invalid increment argument: ${release}`);
        }
        this.raw = this.format();
        if (this.build.length) {
          this.raw += `+${this.build.join(".")}`;
        }
        return this;
      }
    };
    module.exports = SemVer;
  }
});

// node_modules/semver/functions/parse.js
var require_parse = __commonJS({
  "node_modules/semver/functions/parse.js"(exports, module) {
    "use strict";
    var SemVer = require_semver();
    var parse = (version, options, throwErrors = false) => {
      if (version instanceof SemVer) {
        return version;
      }
      try {
        return new SemVer(version, options);
      } catch (er) {
        if (!throwErrors) {
          return null;
        }
        throw er;
      }
    };
    module.exports = parse;
  }
});

// node_modules/semver/functions/valid.js
var require_valid = __commonJS({
  "node_modules/semver/functions/valid.js"(exports, module) {
    "use strict";
    var parse = require_parse();
    var valid = (version, options) => {
      const v = parse(version, options);
      return v ? v.version : null;
    };
    module.exports = valid;
  }
});

// node_modules/semver/functions/clean.js
var require_clean = __commonJS({
  "node_modules/semver/functions/clean.js"(exports, module) {
    "use strict";
    var parse = require_parse();
    var clean = (version, options) => {
      const s = parse(version.trim().replace(/^[=v]+/, ""), options);
      return s ? s.version : null;
    };
    module.exports = clean;
  }
});

// node_modules/semver/functions/inc.js
var require_inc = __commonJS({
  "node_modules/semver/functions/inc.js"(exports, module) {
    "use strict";
    var SemVer = require_semver();
    var inc = (version, release, options, identifier, identifierBase) => {
      if (typeof options === "string") {
        identifierBase = identifier;
        identifier = options;
        options = void 0;
      }
      try {
        return new SemVer(
          version instanceof SemVer ? version.version : version,
          options
        ).inc(release, identifier, identifierBase).version;
      } catch (er) {
        return null;
      }
    };
    module.exports = inc;
  }
});

// node_modules/semver/functions/diff.js
var require_diff = __commonJS({
  "node_modules/semver/functions/diff.js"(exports, module) {
    "use strict";
    var parse = require_parse();
    var diff = (version1, version2) => {
      const v1 = parse(version1, null, true);
      const v2 = parse(version2, null, true);
      const comparison = v1.compare(v2);
      if (comparison === 0) {
        return null;
      }
      const v1Higher = comparison > 0;
      const highVersion = v1Higher ? v1 : v2;
      const lowVersion = v1Higher ? v2 : v1;
      const highHasPre = !!highVersion.prerelease.length;
      const lowHasPre = !!lowVersion.prerelease.length;
      if (lowHasPre && !highHasPre) {
        if (!lowVersion.patch && !lowVersion.minor) {
          return "major";
        }
        if (lowVersion.compareMain(highVersion) === 0) {
          if (lowVersion.minor && !lowVersion.patch) {
            return "minor";
          }
          return "patch";
        }
      }
      const prefix = highHasPre ? "pre" : "";
      if (v1.major !== v2.major) {
        return prefix + "major";
      }
      if (v1.minor !== v2.minor) {
        return prefix + "minor";
      }
      if (v1.patch !== v2.patch) {
        return prefix + "patch";
      }
      return "prerelease";
    };
    module.exports = diff;
  }
});

// node_modules/semver/functions/major.js
var require_major = __commonJS({
  "node_modules/semver/functions/major.js"(exports, module) {
    "use strict";
    var SemVer = require_semver();
    var major = (a, loose) => new SemVer(a, loose).major;
    module.exports = major;
  }
});

// node_modules/semver/functions/minor.js
var require_minor = __commonJS({
  "node_modules/semver/functions/minor.js"(exports, module) {
    "use strict";
    var SemVer = require_semver();
    var minor = (a, loose) => new SemVer(a, loose).minor;
    module.exports = minor;
  }
});

// node_modules/semver/functions/patch.js
var require_patch = __commonJS({
  "node_modules/semver/functions/patch.js"(exports, module) {
    "use strict";
    var SemVer = require_semver();
    var patch = (a, loose) => new SemVer(a, loose).patch;
    module.exports = patch;
  }
});

// node_modules/semver/functions/prerelease.js
var require_prerelease = __commonJS({
  "node_modules/semver/functions/prerelease.js"(exports, module) {
    "use strict";
    var parse = require_parse();
    var prerelease = (version, options) => {
      const parsed = parse(version, options);
      return parsed && parsed.prerelease.length ? parsed.prerelease : null;
    };
    module.exports = prerelease;
  }
});

// node_modules/semver/functions/compare.js
var require_compare = __commonJS({
  "node_modules/semver/functions/compare.js"(exports, module) {
    "use strict";
    var SemVer = require_semver();
    var compare = (a, b, loose) => new SemVer(a, loose).compare(new SemVer(b, loose));
    module.exports = compare;
  }
});

// node_modules/semver/functions/rcompare.js
var require_rcompare = __commonJS({
  "node_modules/semver/functions/rcompare.js"(exports, module) {
    "use strict";
    var compare = require_compare();
    var rcompare = (a, b, loose) => compare(b, a, loose);
    module.exports = rcompare;
  }
});

// node_modules/semver/functions/compare-loose.js
var require_compare_loose = __commonJS({
  "node_modules/semver/functions/compare-loose.js"(exports, module) {
    "use strict";
    var compare = require_compare();
    var compareLoose = (a, b) => compare(a, b, true);
    module.exports = compareLoose;
  }
});

// node_modules/semver/functions/compare-build.js
var require_compare_build = __commonJS({
  "node_modules/semver/functions/compare-build.js"(exports, module) {
    "use strict";
    var SemVer = require_semver();
    var compareBuild = (a, b, loose) => {
      const versionA = new SemVer(a, loose);
      const versionB = new SemVer(b, loose);
      return versionA.compare(versionB) || versionA.compareBuild(versionB);
    };
    module.exports = compareBuild;
  }
});

// node_modules/semver/functions/sort.js
var require_sort = __commonJS({
  "node_modules/semver/functions/sort.js"(exports, module) {
    "use strict";
    var compareBuild = require_compare_build();
    var sort = (list, loose) => list.sort((a, b) => compareBuild(a, b, loose));
    module.exports = sort;
  }
});

// node_modules/semver/functions/rsort.js
var require_rsort = __commonJS({
  "node_modules/semver/functions/rsort.js"(exports, module) {
    "use strict";
    var compareBuild = require_compare_build();
    var rsort = (list, loose) => list.sort((a, b) => compareBuild(b, a, loose));
    module.exports = rsort;
  }
});

// node_modules/semver/functions/gt.js
var require_gt = __commonJS({
  "node_modules/semver/functions/gt.js"(exports, module) {
    "use strict";
    var compare = require_compare();
    var gt = (a, b, loose) => compare(a, b, loose) > 0;
    module.exports = gt;
  }
});

// node_modules/semver/functions/lt.js
var require_lt = __commonJS({
  "node_modules/semver/functions/lt.js"(exports, module) {
    "use strict";
    var compare = require_compare();
    var lt = (a, b, loose) => compare(a, b, loose) < 0;
    module.exports = lt;
  }
});

// node_modules/semver/functions/eq.js
var require_eq = __commonJS({
  "node_modules/semver/functions/eq.js"(exports, module) {
    "use strict";
    var compare = require_compare();
    var eq = (a, b, loose) => compare(a, b, loose) === 0;
    module.exports = eq;
  }
});

// node_modules/semver/functions/neq.js
var require_neq = __commonJS({
  "node_modules/semver/functions/neq.js"(exports, module) {
    "use strict";
    var compare = require_compare();
    var neq = (a, b, loose) => compare(a, b, loose) !== 0;
    module.exports = neq;
  }
});

// node_modules/semver/functions/gte.js
var require_gte = __commonJS({
  "node_modules/semver/functions/gte.js"(exports, module) {
    "use strict";
    var compare = require_compare();
    var gte = (a, b, loose) => compare(a, b, loose) >= 0;
    module.exports = gte;
  }
});

// node_modules/semver/functions/lte.js
var require_lte = __commonJS({
  "node_modules/semver/functions/lte.js"(exports, module) {
    "use strict";
    var compare = require_compare();
    var lte = (a, b, loose) => compare(a, b, loose) <= 0;
    module.exports = lte;
  }
});

// node_modules/semver/functions/cmp.js
var require_cmp = __commonJS({
  "node_modules/semver/functions/cmp.js"(exports, module) {
    "use strict";
    var eq = require_eq();
    var neq = require_neq();
    var gt = require_gt();
    var gte = require_gte();
    var lt = require_lt();
    var lte = require_lte();
    var cmp = (a, op, b, loose) => {
      switch (op) {
        case "===":
          if (typeof a === "object") {
            a = a.version;
          }
          if (typeof b === "object") {
            b = b.version;
          }
          return a === b;
        case "!==":
          if (typeof a === "object") {
            a = a.version;
          }
          if (typeof b === "object") {
            b = b.version;
          }
          return a !== b;
        case "":
        case "=":
        case "==":
          return eq(a, b, loose);
        case "!=":
          return neq(a, b, loose);
        case ">":
          return gt(a, b, loose);
        case ">=":
          return gte(a, b, loose);
        case "<":
          return lt(a, b, loose);
        case "<=":
          return lte(a, b, loose);
        default:
          throw new TypeError(`Invalid operator: ${op}`);
      }
    };
    module.exports = cmp;
  }
});

// node_modules/semver/functions/coerce.js
var require_coerce = __commonJS({
  "node_modules/semver/functions/coerce.js"(exports, module) {
    "use strict";
    var SemVer = require_semver();
    var parse = require_parse();
    var { safeRe: re, t } = require_re();
    var coerce = (version, options) => {
      if (version instanceof SemVer) {
        return version;
      }
      if (typeof version === "number") {
        version = String(version);
      }
      if (typeof version !== "string") {
        return null;
      }
      options = options || {};
      let match = null;
      if (!options.rtl) {
        match = version.match(options.includePrerelease ? re[t.COERCEFULL] : re[t.COERCE]);
      } else {
        const coerceRtlRegex = options.includePrerelease ? re[t.COERCERTLFULL] : re[t.COERCERTL];
        let next;
        while ((next = coerceRtlRegex.exec(version)) && (!match || match.index + match[0].length !== version.length)) {
          if (!match || next.index + next[0].length !== match.index + match[0].length) {
            match = next;
          }
          coerceRtlRegex.lastIndex = next.index + next[1].length + next[2].length;
        }
        coerceRtlRegex.lastIndex = -1;
      }
      if (match === null) {
        return null;
      }
      const major = match[2];
      const minor = match[3] || "0";
      const patch = match[4] || "0";
      const prerelease = options.includePrerelease && match[5] ? `-${match[5]}` : "";
      const build = options.includePrerelease && match[6] ? `+${match[6]}` : "";
      return parse(`${major}.${minor}.${patch}${prerelease}${build}`, options);
    };
    module.exports = coerce;
  }
});

// node_modules/semver/functions/truncate.js
var require_truncate = __commonJS({
  "node_modules/semver/functions/truncate.js"(exports, module) {
    "use strict";
    var parse = require_parse();
    var constants = require_constants();
    var SemVer = require_semver();
    var truncate = (version, truncation, options) => {
      if (!constants.RELEASE_TYPES.includes(truncation)) {
        return null;
      }
      const clonedVersion = cloneInputVersion(version, options);
      return clonedVersion && doTruncation(clonedVersion, truncation);
    };
    var cloneInputVersion = (version, options) => {
      const versionStringToParse = version instanceof SemVer ? version.version : version;
      return parse(versionStringToParse, options);
    };
    var doTruncation = (version, truncation) => {
      if (isPrerelease(truncation)) {
        return version.version;
      }
      version.prerelease = [];
      switch (truncation) {
        case "major":
          version.minor = 0;
          version.patch = 0;
          break;
        case "minor":
          version.patch = 0;
          break;
      }
      return version.format();
    };
    var isPrerelease = (type) => {
      return type.startsWith("pre");
    };
    module.exports = truncate;
  }
});

// node_modules/semver/internal/lrucache.js
var require_lrucache = __commonJS({
  "node_modules/semver/internal/lrucache.js"(exports, module) {
    "use strict";
    var LRUCache = class {
      constructor() {
        this.max = 1e3;
        this.map = /* @__PURE__ */ new Map();
      }
      get(key) {
        const value = this.map.get(key);
        if (value === void 0) {
          return void 0;
        } else {
          this.map.delete(key);
          this.map.set(key, value);
          return value;
        }
      }
      delete(key) {
        return this.map.delete(key);
      }
      set(key, value) {
        const deleted = this.delete(key);
        if (!deleted && value !== void 0) {
          if (this.map.size >= this.max) {
            const firstKey = this.map.keys().next().value;
            this.delete(firstKey);
          }
          this.map.set(key, value);
        }
        return this;
      }
    };
    module.exports = LRUCache;
  }
});

// node_modules/semver/internal/trim-comparator-whitespace.js
var require_trim_comparator_whitespace = __commonJS({
  "node_modules/semver/internal/trim-comparator-whitespace.js"(exports, module) {
    "use strict";
    var {
      MAX_LENGTH,
      MAX_SAFE_BUILD_LENGTH,
      WHITESPACE_CHARACTERS
    } = require_constants();
    var whitespace = new Uint8Array(65536);
    for (const char of WHITESPACE_CHARACTERS) {
      whitespace[char.charCodeAt(0)] = 1;
    }
    var isWhitespace = (char) => char !== void 0 && whitespace[char.charCodeAt(0)] === 1;
    var isVersionPrefix = (char) => char === "v" || char === "=" || isWhitespace(char);
    var isDigit = (char) => char !== void 0 && char >= "0" && char <= "9";
    var isLetter = (char) => char !== void 0 && (char >= "a" && char <= "z" || char >= "A" && char <= "Z");
    var isIdentifierCharacter = (char) => isDigit(char) || isLetter(char) || char === "-";
    var isVersionStart = (char) => isDigit(char) || char === "x" || char === "X" || char === "*";
    var findDigitsEndIndex = (range, start, limit, digitRuns) => {
      if (!isDigit(range[start])) {
        return start;
      }
      if (start >= digitRuns.start && start < digitRuns.end) {
        return Math.min(start + limit, digitRuns.end);
      }
      if (start >= digitRuns.previousStart && start < digitRuns.previousEnd) {
        return Math.min(start + limit, digitRuns.previousEnd);
      }
      let end = start + 1;
      while (isDigit(range[end])) {
        end++;
      }
      digitRuns.previousStart = digitRuns.start;
      digitRuns.previousEnd = digitRuns.end;
      digitRuns.start = start;
      digitRuns.end = end;
      return Math.min(start + limit, end);
    };
    var findVersionNumberEndIndex = (range, start, loose, digitRuns) => {
      if (!loose && range[start] === "0") {
        return start + 1;
      }
      return findDigitsEndIndex(range, start, loose ? MAX_LENGTH : MAX_LENGTH + 1, digitRuns);
    };
    var findPrereleaseIdentifierEndIndex = (range, start, loose, digitRuns) => {
      const digitsEnd = findDigitsEndIndex(range, start, MAX_LENGTH, digitRuns);
      if (isLetter(range[digitsEnd]) || range[digitsEnd] === "-") {
        let end = digitsEnd + 1;
        const limit = end + MAX_SAFE_BUILD_LENGTH;
        while (end < limit && isIdentifierCharacter(range[end])) {
          end++;
        }
        return end;
      }
      return findVersionNumberEndIndex(range, start, loose, digitRuns);
    };
    var findPrereleaseEndIndex = (range, start, loose, digitRuns) => {
      const hyphen = range[start] === "-";
      if (!loose && !hyphen) {
        return start;
      }
      const identifierStart = start + (hyphen ? 1 : 0);
      let end = findPrereleaseIdentifierEndIndex(range, identifierStart, loose, digitRuns);
      if (end === identifierStart) {
        if (!loose || !hyphen) {
          return start;
        }
        end = findPrereleaseIdentifierEndIndex(range, start, loose, digitRuns);
      }
      while (range[end] === ".") {
        const next = findPrereleaseIdentifierEndIndex(range, end + 1, loose, digitRuns);
        if (next === end + 1) {
          break;
        }
        end = next;
      }
      return end;
    };
    var findBuildIdentifierEndIndex = (range, start) => {
      let end = start;
      while (end - start < MAX_SAFE_BUILD_LENGTH && isIdentifierCharacter(range[end])) {
        end++;
      }
      return end;
    };
    var findBuildEndIndex = (range, start) => {
      if (range[start] !== "+") {
        return start;
      }
      let end = findBuildIdentifierEndIndex(range, start + 1);
      if (end === start + 1) {
        return start;
      }
      while (range[end] === ".") {
        const next = findBuildIdentifierEndIndex(range, end + 1);
        if (next === end + 1) {
          break;
        }
        end = next;
      }
      return end;
    };
    var findLooseFullVersionEndIndex = (range, start, digitRuns) => {
      let end = start;
      for (let component = 0; component < 3; component++) {
        const next = findVersionNumberEndIndex(range, end, true, digitRuns);
        if (next === end) {
          return start;
        }
        end = next;
        if (component < 2) {
          if (range[end] !== ".") {
            return start;
          }
          end++;
        }
      }
      const prereleaseEnd = findPrereleaseEndIndex(range, end, true, digitRuns);
      return findBuildEndIndex(range, prereleaseEnd);
    };
    var findPartialVersionComponentEndIndex = (range, start, digitRuns) => {
      if (isDigit(range[start])) {
        return findVersionNumberEndIndex(range, start, false, digitRuns);
      }
      return isVersionStart(range[start]) ? start + 1 : start;
    };
    var findPartialVersionEndIndex = (range, start, digitRuns) => {
      let end = findPartialVersionComponentEndIndex(range, start, digitRuns);
      for (let component = 0; component < 2; component++) {
        if (range[end] !== ".") {
          return end;
        }
        const next = findPartialVersionComponentEndIndex(range, end + 1, digitRuns);
        if (next === end + 1) {
          return end;
        }
        end = next;
      }
      const prereleaseEnd = findPrereleaseEndIndex(range, end, false, digitRuns);
      return findBuildEndIndex(range, prereleaseEnd);
    };
    var findVersionEndIndex = (range, start, digitRuns) => {
      const fullVersionEnd = findLooseFullVersionEndIndex(range, start, digitRuns);
      return fullVersionEnd !== start ? fullVersionEnd : findPartialVersionEndIndex(range, start, digitRuns);
    };
    var findRemovableWhitespaceIndex = (range, matchStart) => {
      let position = matchStart;
      if (isWhitespace(range[position])) {
        position++;
      }
      if (range[position] === "<" || range[position] === ">") {
        position++;
      }
      if (range[position] === "=") {
        position++;
      }
      return isWhitespace(range[position]) ? position : -1;
    };
    var trimComparatorWhitespace = (range) => {
      let result = "";
      let copyFrom = 0;
      let cursor = 0;
      const digitRuns = { start: -1, end: -1, previousStart: -1, previousEnd: -1 };
      while (cursor < range.length) {
        const matchStart = cursor;
        if (range[cursor] === "<" || range[cursor] === ">") {
          cursor++;
        } else if (!isVersionPrefix(range[cursor]) && !isVersionStart(range[cursor])) {
          cursor++;
          continue;
        }
        while (cursor < range.length && isVersionPrefix(range[cursor])) {
          cursor++;
        }
        if (!isVersionStart(range[cursor])) {
          continue;
        }
        const whitespacePosition = findRemovableWhitespaceIndex(range, matchStart);
        if (whitespacePosition !== -1) {
          result += range.slice(copyFrom, whitespacePosition);
          copyFrom = whitespacePosition + 1;
        }
        cursor = findVersionEndIndex(range, cursor, digitRuns);
      }
      return result + range.slice(copyFrom);
    };
    module.exports = trimComparatorWhitespace;
  }
});

// node_modules/semver/classes/range.js
var require_range = __commonJS({
  "node_modules/semver/classes/range.js"(exports, module) {
    "use strict";
    var SPACE_CHARACTERS = /\s+/g;
    var Range = class _Range {
      constructor(range, options) {
        options = parseOptions(options);
        if (range instanceof _Range) {
          if (range.loose === !!options.loose && range.includePrerelease === !!options.includePrerelease) {
            return range;
          } else {
            return new _Range(range.raw, options);
          }
        }
        if (range instanceof Comparator) {
          this.raw = range.value;
          this.set = [[range]];
          this.formatted = void 0;
          return this;
        }
        this.options = options;
        this.loose = !!options.loose;
        this.includePrerelease = !!options.includePrerelease;
        this.raw = range.trim().replace(SPACE_CHARACTERS, " ");
        this.set = this.raw.split("||").map((r) => this.parseRange(r.trim())).filter((c) => c.length);
        if (!this.set.length) {
          throw new TypeError(`Invalid SemVer Range: ${this.raw}`);
        }
        if (this.set.length > 1) {
          const first = this.set[0];
          this.set = this.set.filter((c) => !isNullSet(c[0]));
          if (this.set.length === 0) {
            this.set = [first];
          } else if (this.set.length > 1) {
            for (const c of this.set) {
              if (c.length === 1 && isAny(c[0])) {
                this.set = [c];
                break;
              }
            }
          }
        }
        this.formatted = void 0;
      }
      get range() {
        if (this.formatted === void 0) {
          this.formatted = "";
          for (let i = 0; i < this.set.length; i++) {
            if (i > 0) {
              this.formatted += "||";
            }
            const comps = this.set[i];
            for (let k = 0; k < comps.length; k++) {
              if (k > 0) {
                this.formatted += " ";
              }
              this.formatted += comps[k].toString().trim();
            }
          }
        }
        return this.formatted;
      }
      format() {
        return this.range;
      }
      toString() {
        return this.range;
      }
      parseRange(range) {
        range = range.replace(BUILDSTRIPRE, "");
        const memoOpts = (this.options.includePrerelease && FLAG_INCLUDE_PRERELEASE) | (this.options.loose && FLAG_LOOSE);
        const memoKey = memoOpts + ":" + range;
        const cached = cache.get(memoKey);
        if (cached) {
          return cached;
        }
        const loose = this.options.loose;
        const hr = loose ? re[t.HYPHENRANGELOOSE] : re[t.HYPHENRANGE];
        range = range.replace(hr, hyphenReplace(this.options.includePrerelease));
        debug("hyphen replace", range);
        range = trimComparatorWhitespace(range);
        debug("comparator trim", range);
        range = range.replace(re[t.TILDETRIM], tildeTrimReplace);
        debug("tilde trim", range);
        range = range.replace(re[t.CARETTRIM], caretTrimReplace);
        debug("caret trim", range);
        let rangeList = range.split(" ").map((comp) => parseComparator(comp, this.options)).join(" ").split(/\s+/).map((comp) => replaceGTE0(comp, this.options));
        if (loose) {
          rangeList = rangeList.filter((comp) => {
            debug("loose invalid filter", comp, this.options);
            return !!comp.match(re[t.COMPARATORLOOSE]);
          });
        }
        debug("range list", rangeList);
        const rangeMap = /* @__PURE__ */ new Map();
        const comparators = rangeList.map((comp) => new Comparator(comp, this.options));
        for (const comp of comparators) {
          if (isNullSet(comp)) {
            return [comp];
          }
          rangeMap.set(comp.value, comp);
        }
        if (rangeMap.size > 1 && rangeMap.has("")) {
          rangeMap.delete("");
        }
        const result = [...rangeMap.values()];
        cache.set(memoKey, result);
        return result;
      }
      intersects(range, options) {
        if (!(range instanceof _Range)) {
          throw new TypeError("a Range is required");
        }
        return this.set.some((thisComparators) => {
          return isSatisfiable(thisComparators, options) && range.set.some((rangeComparators) => {
            return isSatisfiable(rangeComparators, options) && thisComparators.every((thisComparator) => {
              return rangeComparators.every((rangeComparator) => {
                return thisComparator.intersects(rangeComparator, options);
              });
            });
          });
        });
      }
      // if ANY of the sets match ALL of its comparators, then pass
      test(version) {
        if (!version) {
          return false;
        }
        if (typeof version === "string") {
          try {
            version = new SemVer(version, this.options);
          } catch (er) {
            return false;
          }
        }
        for (let i = 0; i < this.set.length; i++) {
          if (testSet(this.set[i], version, this.options)) {
            return true;
          }
        }
        return false;
      }
    };
    module.exports = Range;
    var LRU = require_lrucache();
    var cache = new LRU();
    var parseOptions = require_parse_options();
    var Comparator = require_comparator();
    var debug = require_debug();
    var SemVer = require_semver();
    var trimComparatorWhitespace = require_trim_comparator_whitespace();
    var {
      safeRe: re,
      src,
      t,
      tildeTrimReplace,
      caretTrimReplace
    } = require_re();
    var { FLAG_INCLUDE_PRERELEASE, FLAG_LOOSE } = require_constants();
    var BUILDSTRIPRE = new RegExp(src[t.BUILD], "g");
    var isNullSet = (c) => c.value === "<0.0.0-0";
    var isAny = (c) => c.value === "";
    var isSatisfiable = (comparators, options) => {
      let result = true;
      const remainingComparators = comparators.slice();
      let testComparator = remainingComparators.pop();
      while (result && remainingComparators.length) {
        result = remainingComparators.every((otherComparator) => {
          return testComparator.intersects(otherComparator, options);
        });
        testComparator = remainingComparators.pop();
      }
      return result;
    };
    var parseComparator = (comp, options) => {
      comp = comp.replace(re[t.BUILD], "");
      debug("comp", comp, options);
      comp = replaceCarets(comp, options);
      debug("caret", comp);
      comp = replaceTildes(comp, options);
      debug("tildes", comp);
      comp = replaceXRanges(comp, options);
      debug("xrange", comp);
      comp = replaceStars(comp, options);
      debug("stars", comp);
      return comp;
    };
    var isX = (id) => !id || id.toLowerCase() === "x" || id === "*";
    var invalidXRangeOrder = (M, m, p) => isX(M) && !isX(m) || isX(m) && p && !isX(p);
    var replaceTildes = (comp, options) => {
      return comp.trim().split(/\s+/).map((c) => replaceTilde(c, options)).join(" ");
    };
    var replaceTilde = (comp, options) => {
      const r = options.loose ? re[t.TILDELOOSE] : re[t.TILDE];
      const z = options.includePrerelease ? "-0" : "";
      return comp.replace(r, (_, M, m, p, pr) => {
        debug("tilde", comp, _, M, m, p, pr);
        let ret;
        if (isX(M)) {
          ret = "";
        } else if (isX(m)) {
          ret = `>=${M}.0.0${z} <${+M + 1}.0.0-0`;
        } else if (isX(p)) {
          ret = `>=${M}.${m}.0${z} <${M}.${+m + 1}.0-0`;
        } else if (pr) {
          debug("replaceTilde pr", pr);
          ret = `>=${M}.${m}.${p}-${pr} <${M}.${+m + 1}.0-0`;
        } else {
          ret = `>=${M}.${m}.${p} <${M}.${+m + 1}.0-0`;
        }
        debug("tilde return", ret);
        return ret;
      });
    };
    var replaceCarets = (comp, options) => {
      return comp.trim().split(/\s+/).map((c) => replaceCaret(c, options)).join(" ");
    };
    var replaceCaret = (comp, options) => {
      debug("caret", comp, options);
      const r = options.loose ? re[t.CARETLOOSE] : re[t.CARET];
      const z = options.includePrerelease ? "-0" : "";
      return comp.replace(r, (_, M, m, p, pr) => {
        debug("caret", comp, _, M, m, p, pr);
        let ret;
        if (isX(M)) {
          ret = "";
        } else if (isX(m)) {
          ret = `>=${M}.0.0${z} <${+M + 1}.0.0-0`;
        } else if (isX(p)) {
          if (M === "0") {
            ret = `>=${M}.${m}.0${z} <${M}.${+m + 1}.0-0`;
          } else {
            ret = `>=${M}.${m}.0${z} <${+M + 1}.0.0-0`;
          }
        } else if (pr) {
          debug("replaceCaret pr", pr);
          if (M === "0") {
            if (m === "0") {
              ret = `>=${M}.${m}.${p}-${pr} <${M}.${m}.${+p + 1}-0`;
            } else {
              ret = `>=${M}.${m}.${p}-${pr} <${M}.${+m + 1}.0-0`;
            }
          } else {
            ret = `>=${M}.${m}.${p}-${pr} <${+M + 1}.0.0-0`;
          }
        } else {
          debug("no pr");
          if (M === "0") {
            if (m === "0") {
              ret = `>=${M}.${m}.${p} <${M}.${m}.${+p + 1}-0`;
            } else {
              ret = `>=${M}.${m}.${p} <${M}.${+m + 1}.0-0`;
            }
          } else {
            ret = `>=${M}.${m}.${p} <${+M + 1}.0.0-0`;
          }
        }
        debug("caret return", ret);
        return ret;
      });
    };
    var replaceXRanges = (comp, options) => {
      debug("replaceXRanges", comp, options);
      return comp.split(/\s+/).map((c) => replaceXRange(c, options)).join(" ");
    };
    var replaceXRange = (comp, options) => {
      comp = comp.trim();
      const r = options.loose ? re[t.XRANGELOOSE] : re[t.XRANGE];
      return comp.replace(r, (ret, gtlt, M, m, p, pr) => {
        debug("xRange", comp, ret, gtlt, M, m, p, pr);
        if (invalidXRangeOrder(M, m, p)) {
          return comp;
        }
        const xM = isX(M);
        const xm = xM || isX(m);
        const xp = xm || isX(p);
        const anyX = xp;
        if (gtlt === "=" && anyX) {
          gtlt = "";
        }
        pr = options.includePrerelease ? "-0" : "";
        if (xM) {
          if (gtlt === ">" || gtlt === "<") {
            ret = "<0.0.0-0";
          } else {
            ret = "*";
          }
        } else if (gtlt && anyX) {
          if (xm) {
            m = 0;
          }
          p = 0;
          if (gtlt === ">") {
            gtlt = ">=";
            if (xm) {
              M = +M + 1;
              m = 0;
              p = 0;
            } else {
              m = +m + 1;
              p = 0;
            }
          } else if (gtlt === "<=") {
            gtlt = "<";
            if (xm) {
              M = +M + 1;
            } else {
              m = +m + 1;
            }
          }
          if (gtlt === "<") {
            pr = "-0";
          }
          ret = `${gtlt + M}.${m}.${p}${pr}`;
        } else if (xm) {
          ret = `>=${M}.0.0${pr} <${+M + 1}.0.0-0`;
        } else if (xp) {
          ret = `>=${M}.${m}.0${pr} <${M}.${+m + 1}.0-0`;
        }
        debug("xRange return", ret);
        return ret;
      });
    };
    var replaceStars = (comp, options) => {
      debug("replaceStars", comp, options);
      return comp.trim().replace(re[t.STAR], "");
    };
    var replaceGTE0 = (comp, options) => {
      debug("replaceGTE0", comp, options);
      return comp.trim().replace(re[options.includePrerelease ? t.GTE0PRE : t.GTE0], "");
    };
    var hyphenReplace = (incPr) => ($0, from, fM, fm, fp, fpr, fb, to, tM, tm, tp, tpr) => {
      if (isX(fM)) {
        from = "";
      } else if (isX(fm)) {
        from = `>=${fM}.0.0${incPr ? "-0" : ""}`;
      } else if (isX(fp)) {
        from = `>=${fM}.${fm}.0${incPr ? "-0" : ""}`;
      } else if (fpr) {
        from = `>=${from}`;
      } else {
        from = `>=${from}${incPr ? "-0" : ""}`;
      }
      if (isX(tM)) {
        to = "";
      } else if (isX(tm)) {
        to = `<${+tM + 1}.0.0-0`;
      } else if (isX(tp)) {
        to = `<${tM}.${+tm + 1}.0-0`;
      } else if (tpr) {
        to = `<=${tM}.${tm}.${tp}-${tpr}`;
      } else if (incPr) {
        to = `<${tM}.${tm}.${+tp + 1}-0`;
      } else {
        to = `<=${to}`;
      }
      return `${from} ${to}`.trim();
    };
    var testSet = (set, version, options) => {
      for (let i = 0; i < set.length; i++) {
        if (!set[i].test(version)) {
          return false;
        }
      }
      if (version.prerelease.length && !options.includePrerelease) {
        for (let i = 0; i < set.length; i++) {
          debug(set[i].semver);
          if (set[i].semver === Comparator.ANY) {
            continue;
          }
          if (set[i].semver.prerelease.length > 0) {
            const allowed = set[i].semver;
            if (allowed.major === version.major && allowed.minor === version.minor && allowed.patch === version.patch) {
              return true;
            }
          }
        }
        return false;
      }
      return true;
    };
  }
});

// node_modules/semver/classes/comparator.js
var require_comparator = __commonJS({
  "node_modules/semver/classes/comparator.js"(exports, module) {
    "use strict";
    var ANY = /* @__PURE__ */ Symbol("SemVer ANY");
    var Comparator = class _Comparator {
      static get ANY() {
        return ANY;
      }
      constructor(comp, options) {
        options = parseOptions(options);
        if (comp instanceof _Comparator) {
          if (comp.loose === !!options.loose) {
            return comp;
          } else {
            comp = comp.value;
          }
        }
        comp = comp.trim().split(/\s+/).join(" ");
        debug("comparator", comp, options);
        this.options = options;
        this.loose = !!options.loose;
        this.parse(comp);
        if (this.semver === ANY) {
          this.value = "";
        } else {
          this.value = this.operator + this.semver.version;
        }
        debug("comp", this);
      }
      parse(comp) {
        const r = this.options.loose ? re[t.COMPARATORLOOSE] : re[t.COMPARATOR];
        const m = comp.match(r);
        if (!m) {
          throw new TypeError(`Invalid comparator: ${comp}`);
        }
        this.operator = m[1] !== void 0 ? m[1] : "";
        if (this.operator === "=") {
          this.operator = "";
        }
        if (!m[2]) {
          this.semver = ANY;
        } else {
          this.semver = new SemVer(m[2], this.options.loose);
        }
      }
      toString() {
        return this.value;
      }
      test(version) {
        debug("Comparator.test", version, this.options.loose);
        if (this.semver === ANY || version === ANY) {
          return true;
        }
        if (typeof version === "string") {
          try {
            version = new SemVer(version, this.options);
          } catch (er) {
            return false;
          }
        }
        return cmp(version, this.operator, this.semver, this.options);
      }
      intersects(comp, options) {
        if (!(comp instanceof _Comparator)) {
          throw new TypeError("a Comparator is required");
        }
        if (this.operator === "") {
          if (this.value === "") {
            return true;
          }
          return new Range(comp.value, options).test(this.value);
        } else if (comp.operator === "") {
          if (comp.value === "") {
            return true;
          }
          return new Range(this.value, options).test(comp.semver);
        }
        options = parseOptions(options);
        if (options.includePrerelease && (this.value === "<0.0.0-0" || comp.value === "<0.0.0-0")) {
          return false;
        }
        if (!options.includePrerelease && (this.value.startsWith("<0.0.0") || comp.value.startsWith("<0.0.0"))) {
          return false;
        }
        if (this.operator.startsWith(">") && comp.operator.startsWith(">")) {
          return true;
        }
        if (this.operator.startsWith("<") && comp.operator.startsWith("<")) {
          return true;
        }
        if (this.semver.version === comp.semver.version && this.operator.includes("=") && comp.operator.includes("=")) {
          return true;
        }
        if (cmp(this.semver, "<", comp.semver, options) && this.operator.startsWith(">") && comp.operator.startsWith("<")) {
          return true;
        }
        if (cmp(this.semver, ">", comp.semver, options) && this.operator.startsWith("<") && comp.operator.startsWith(">")) {
          return true;
        }
        return false;
      }
    };
    module.exports = Comparator;
    var parseOptions = require_parse_options();
    var { safeRe: re, t } = require_re();
    var cmp = require_cmp();
    var debug = require_debug();
    var SemVer = require_semver();
    var Range = require_range();
  }
});

// node_modules/semver/functions/satisfies.js
var require_satisfies = __commonJS({
  "node_modules/semver/functions/satisfies.js"(exports, module) {
    "use strict";
    var Range = require_range();
    var satisfies = (version, range, options) => {
      try {
        range = new Range(range, options);
      } catch (er) {
        return false;
      }
      return range.test(version);
    };
    module.exports = satisfies;
  }
});

// node_modules/semver/ranges/to-comparators.js
var require_to_comparators = __commonJS({
  "node_modules/semver/ranges/to-comparators.js"(exports, module) {
    "use strict";
    var Range = require_range();
    var toComparators = (range, options) => new Range(range, options).set.map((comp) => comp.map((c) => c.value).join(" ").trim().split(" "));
    module.exports = toComparators;
  }
});

// node_modules/semver/ranges/max-satisfying.js
var require_max_satisfying = __commonJS({
  "node_modules/semver/ranges/max-satisfying.js"(exports, module) {
    "use strict";
    var SemVer = require_semver();
    var Range = require_range();
    var maxSatisfying = (versions, range, options) => {
      let max = null;
      let maxSV = null;
      let rangeObj = null;
      try {
        rangeObj = new Range(range, options);
      } catch (er) {
        return null;
      }
      versions.forEach((v) => {
        if (rangeObj.test(v)) {
          if (!max || maxSV.compare(v) === -1) {
            max = v;
            maxSV = new SemVer(max, options);
          }
        }
      });
      return max;
    };
    module.exports = maxSatisfying;
  }
});

// node_modules/semver/ranges/min-satisfying.js
var require_min_satisfying = __commonJS({
  "node_modules/semver/ranges/min-satisfying.js"(exports, module) {
    "use strict";
    var SemVer = require_semver();
    var Range = require_range();
    var minSatisfying = (versions, range, options) => {
      let min = null;
      let minSV = null;
      let rangeObj = null;
      try {
        rangeObj = new Range(range, options);
      } catch (er) {
        return null;
      }
      versions.forEach((v) => {
        if (rangeObj.test(v)) {
          if (!min || minSV.compare(v) === 1) {
            min = v;
            minSV = new SemVer(min, options);
          }
        }
      });
      return min;
    };
    module.exports = minSatisfying;
  }
});

// node_modules/semver/ranges/min-version.js
var require_min_version = __commonJS({
  "node_modules/semver/ranges/min-version.js"(exports, module) {
    "use strict";
    var SemVer = require_semver();
    var Range = require_range();
    var gt = require_gt();
    var minVersion = (range, loose) => {
      range = new Range(range, loose);
      let minver = new SemVer("0.0.0");
      if (range.test(minver)) {
        return minver;
      }
      minver = new SemVer("0.0.0-0");
      if (range.test(minver)) {
        return minver;
      }
      minver = null;
      for (let i = 0; i < range.set.length; ++i) {
        const comparators = range.set[i];
        let setMin = null;
        comparators.forEach((comparator) => {
          const compver = new SemVer(comparator.semver.version);
          switch (comparator.operator) {
            case ">":
              if (compver.prerelease.length === 0) {
                compver.patch++;
              } else {
                compver.prerelease.push(0);
              }
              compver.raw = compver.format();
            /* fallthrough */
            case "":
            case ">=":
              if (!setMin || gt(compver, setMin)) {
                setMin = compver;
              }
              break;
            case "<":
            case "<=":
              break;
            /* istanbul ignore next */
            default:
              throw new Error(`Unexpected operation: ${comparator.operator}`);
          }
        });
        if (setMin && (!minver || gt(minver, setMin))) {
          minver = setMin;
        }
      }
      if (minver && range.test(minver)) {
        return minver;
      }
      return null;
    };
    module.exports = minVersion;
  }
});

// node_modules/semver/ranges/valid.js
var require_valid2 = __commonJS({
  "node_modules/semver/ranges/valid.js"(exports, module) {
    "use strict";
    var Range = require_range();
    var validRange = (range, options) => {
      try {
        return new Range(range, options).range || "*";
      } catch (er) {
        return null;
      }
    };
    module.exports = validRange;
  }
});

// node_modules/semver/ranges/outside.js
var require_outside = __commonJS({
  "node_modules/semver/ranges/outside.js"(exports, module) {
    "use strict";
    var SemVer = require_semver();
    var Comparator = require_comparator();
    var { ANY } = Comparator;
    var Range = require_range();
    var satisfies = require_satisfies();
    var gt = require_gt();
    var lt = require_lt();
    var lte = require_lte();
    var gte = require_gte();
    var outside = (version, range, hilo, options) => {
      version = new SemVer(version, options);
      range = new Range(range, options);
      let gtfn, ltefn, ltfn, comp, ecomp;
      switch (hilo) {
        case ">":
          gtfn = gt;
          ltefn = lte;
          ltfn = lt;
          comp = ">";
          ecomp = ">=";
          break;
        case "<":
          gtfn = lt;
          ltefn = gte;
          ltfn = gt;
          comp = "<";
          ecomp = "<=";
          break;
        default:
          throw new TypeError('Must provide a hilo val of "<" or ">"');
      }
      if (satisfies(version, range, options)) {
        return false;
      }
      for (let i = 0; i < range.set.length; ++i) {
        const comparators = range.set[i];
        let high = null;
        let low = null;
        comparators.forEach((comparator) => {
          if (comparator.semver === ANY) {
            comparator = new Comparator(">=0.0.0");
          }
          high = high || comparator;
          low = low || comparator;
          if (gtfn(comparator.semver, high.semver, options)) {
            high = comparator;
          } else if (ltfn(comparator.semver, low.semver, options)) {
            low = comparator;
          }
        });
        if (high.operator === comp || high.operator === ecomp) {
          return false;
        }
        if ((!low.operator || low.operator === comp) && ltefn(version, low.semver)) {
          return false;
        } else if (low.operator === ecomp && ltfn(version, low.semver)) {
          return false;
        }
      }
      return true;
    };
    module.exports = outside;
  }
});

// node_modules/semver/ranges/gtr.js
var require_gtr = __commonJS({
  "node_modules/semver/ranges/gtr.js"(exports, module) {
    "use strict";
    var outside = require_outside();
    var gtr = (version, range, options) => outside(version, range, ">", options);
    module.exports = gtr;
  }
});

// node_modules/semver/ranges/ltr.js
var require_ltr = __commonJS({
  "node_modules/semver/ranges/ltr.js"(exports, module) {
    "use strict";
    var outside = require_outside();
    var ltr = (version, range, options) => outside(version, range, "<", options);
    module.exports = ltr;
  }
});

// node_modules/semver/ranges/intersects.js
var require_intersects = __commonJS({
  "node_modules/semver/ranges/intersects.js"(exports, module) {
    "use strict";
    var Range = require_range();
    var intersects = (r1, r2, options) => {
      r1 = new Range(r1, options);
      r2 = new Range(r2, options);
      return r1.intersects(r2, options);
    };
    module.exports = intersects;
  }
});

// node_modules/semver/ranges/simplify.js
var require_simplify = __commonJS({
  "node_modules/semver/ranges/simplify.js"(exports, module) {
    "use strict";
    var satisfies = require_satisfies();
    var compare = require_compare();
    module.exports = (versions, range, options) => {
      const set = [];
      let first = null;
      let prev = null;
      const v = versions.sort((a, b) => compare(a, b, options));
      for (const version of v) {
        const included = satisfies(version, range, options);
        if (included) {
          prev = version;
          if (!first) {
            first = version;
          }
        } else {
          if (prev) {
            set.push([first, prev]);
          }
          prev = null;
          first = null;
        }
      }
      if (first) {
        set.push([first, null]);
      }
      const ranges = [];
      for (const [min, max] of set) {
        if (min === max) {
          ranges.push(min);
        } else if (!max && min === v[0]) {
          ranges.push("*");
        } else if (!max) {
          ranges.push(`>=${min}`);
        } else if (min === v[0]) {
          ranges.push(`<=${max}`);
        } else {
          ranges.push(`${min} - ${max}`);
        }
      }
      const simplified = ranges.join(" || ");
      const original = typeof range.raw === "string" ? range.raw : String(range);
      return simplified.length < original.length ? simplified : range;
    };
  }
});

// node_modules/semver/ranges/subset.js
var require_subset = __commonJS({
  "node_modules/semver/ranges/subset.js"(exports, module) {
    "use strict";
    var Range = require_range();
    var Comparator = require_comparator();
    var { ANY } = Comparator;
    var satisfies = require_satisfies();
    var compare = require_compare();
    var subset = (sub, dom, options = {}) => {
      if (sub === dom) {
        return true;
      }
      sub = new Range(sub, options);
      dom = new Range(dom, options);
      let sawNonNull = false;
      OUTER: for (const simpleSub of sub.set) {
        for (const simpleDom of dom.set) {
          const isSub = simpleSubset(simpleSub, simpleDom, options);
          sawNonNull = sawNonNull || isSub !== null;
          if (isSub) {
            continue OUTER;
          }
        }
        if (sawNonNull) {
          return false;
        }
      }
      return true;
    };
    var minimumVersionWithPreRelease = [new Comparator(">=0.0.0-0")];
    var minimumVersion = [new Comparator(">=0.0.0")];
    var simpleSubset = (sub, dom, options) => {
      if (sub === dom) {
        return true;
      }
      if (sub.length === 1 && sub[0].semver === ANY) {
        if (dom.length === 1 && dom[0].semver === ANY) {
          return true;
        } else if (options.includePrerelease) {
          sub = minimumVersionWithPreRelease;
        } else {
          sub = minimumVersion;
        }
      }
      if (dom.length === 1 && dom[0].semver === ANY) {
        if (options.includePrerelease) {
          return true;
        } else {
          dom = minimumVersion;
        }
      }
      const eqSet = /* @__PURE__ */ new Set();
      let gt, lt;
      for (const c of sub) {
        if (c.operator === ">" || c.operator === ">=") {
          gt = higherGT(gt, c, options);
        } else if (c.operator === "<" || c.operator === "<=") {
          lt = lowerLT(lt, c, options);
        } else {
          eqSet.add(c.semver);
        }
      }
      if (eqSet.size > 1) {
        return null;
      }
      let gtltComp;
      if (gt && lt) {
        gtltComp = compare(gt.semver, lt.semver, options);
        if (gtltComp > 0) {
          return null;
        } else if (gtltComp === 0 && (gt.operator !== ">=" || lt.operator !== "<=")) {
          return null;
        }
      }
      for (const eq of eqSet) {
        if (gt && !satisfies(eq, String(gt), options)) {
          return null;
        }
        if (lt && !satisfies(eq, String(lt), options)) {
          return null;
        }
        for (const c of dom) {
          if (!satisfies(eq, String(c), options)) {
            return false;
          }
        }
        return true;
      }
      let higher, lower;
      let hasDomLT, hasDomGT;
      let needDomLTPre = lt && !options.includePrerelease && lt.semver.prerelease.length ? lt.semver : false;
      let needDomGTPre = gt && !options.includePrerelease && gt.semver.prerelease.length ? gt.semver : false;
      if (needDomLTPre && needDomLTPre.prerelease.length === 1 && lt.operator === "<" && needDomLTPre.prerelease[0] === 0) {
        needDomLTPre = false;
      }
      for (const c of dom) {
        hasDomGT = hasDomGT || c.operator === ">" || c.operator === ">=";
        hasDomLT = hasDomLT || c.operator === "<" || c.operator === "<=";
        if (gt) {
          if (needDomGTPre) {
            if (c.semver.prerelease && c.semver.prerelease.length && c.semver.major === needDomGTPre.major && c.semver.minor === needDomGTPre.minor && c.semver.patch === needDomGTPre.patch) {
              needDomGTPre = false;
            }
          }
          if (c.operator === ">" || c.operator === ">=") {
            higher = higherGT(gt, c, options);
            if (higher === c && higher !== gt) {
              return false;
            }
          } else if (gt.operator === ">=" && !c.test(gt.semver)) {
            return false;
          }
        }
        if (lt) {
          if (needDomLTPre) {
            if (c.semver.prerelease && c.semver.prerelease.length && c.semver.major === needDomLTPre.major && c.semver.minor === needDomLTPre.minor && c.semver.patch === needDomLTPre.patch) {
              needDomLTPre = false;
            }
          }
          if (c.operator === "<" || c.operator === "<=") {
            lower = lowerLT(lt, c, options);
            if (lower === c && lower !== lt) {
              return false;
            }
          } else if (lt.operator === "<=" && !c.test(lt.semver)) {
            return false;
          }
        }
        if (!c.operator && (lt || gt) && gtltComp !== 0) {
          return false;
        }
      }
      if (gt && hasDomLT && !lt && gtltComp !== 0) {
        return false;
      }
      if (lt && hasDomGT && !gt && gtltComp !== 0) {
        return false;
      }
      if (needDomGTPre || needDomLTPre) {
        return false;
      }
      return true;
    };
    var higherGT = (a, b, options) => {
      if (!a) {
        return b;
      }
      const comp = compare(a.semver, b.semver, options);
      return comp > 0 ? a : comp < 0 ? b : b.operator === ">" && a.operator === ">=" ? b : a;
    };
    var lowerLT = (a, b, options) => {
      if (!a) {
        return b;
      }
      const comp = compare(a.semver, b.semver, options);
      return comp < 0 ? a : comp > 0 ? b : b.operator === "<" && a.operator === "<=" ? b : a;
    };
    module.exports = subset;
  }
});

// node_modules/semver/index.js
var require_semver2 = __commonJS({
  "node_modules/semver/index.js"(exports, module) {
    "use strict";
    var internalRe = require_re();
    var constants = require_constants();
    var SemVer = require_semver();
    var identifiers = require_identifiers();
    var parse = require_parse();
    var valid = require_valid();
    var clean = require_clean();
    var inc = require_inc();
    var diff = require_diff();
    var major = require_major();
    var minor = require_minor();
    var patch = require_patch();
    var prerelease = require_prerelease();
    var compare = require_compare();
    var rcompare = require_rcompare();
    var compareLoose = require_compare_loose();
    var compareBuild = require_compare_build();
    var sort = require_sort();
    var rsort = require_rsort();
    var gt = require_gt();
    var lt = require_lt();
    var eq = require_eq();
    var neq = require_neq();
    var gte = require_gte();
    var lte = require_lte();
    var cmp = require_cmp();
    var coerce = require_coerce();
    var truncate = require_truncate();
    var Comparator = require_comparator();
    var Range = require_range();
    var satisfies = require_satisfies();
    var toComparators = require_to_comparators();
    var maxSatisfying = require_max_satisfying();
    var minSatisfying = require_min_satisfying();
    var minVersion = require_min_version();
    var validRange = require_valid2();
    var outside = require_outside();
    var gtr = require_gtr();
    var ltr = require_ltr();
    var intersects = require_intersects();
    var simplifyRange = require_simplify();
    var subset = require_subset();
    module.exports = {
      parse,
      valid,
      clean,
      inc,
      diff,
      major,
      minor,
      patch,
      prerelease,
      compare,
      rcompare,
      compareLoose,
      compareBuild,
      sort,
      rsort,
      gt,
      lt,
      eq,
      neq,
      gte,
      lte,
      cmp,
      coerce,
      truncate,
      Comparator,
      Range,
      satisfies,
      toComparators,
      maxSatisfying,
      minSatisfying,
      minVersion,
      validRange,
      outside,
      gtr,
      ltr,
      intersects,
      simplifyRange,
      subset,
      SemVer,
      re: internalRe.re,
      src: internalRe.src,
      tokens: internalRe.t,
      SEMVER_SPEC_VERSION: constants.SEMVER_SPEC_VERSION,
      RELEASE_TYPES: constants.RELEASE_TYPES,
      compareIdentifiers: identifiers.compareIdentifiers,
      rcompareIdentifiers: identifiers.rcompareIdentifiers
    };
  }
});

// node_modules/@metamask/auto-changelog/dist/parse-changelog.js
var import_semver2 = __toESM(require_semver2());

// node_modules/@metamask/auto-changelog/dist/changelog.js
var import_semver = __toESM(require_semver2(), 1);

// node_modules/@metamask/auto-changelog/dist/constants.js
var ConventionalCommitType;
(function(ConventionalCommitType2) {
  ConventionalCommitType2["FEAT"] = "feat";
  ConventionalCommitType2["FIX"] = "fix";
  ConventionalCommitType2["DOCS"] = "docs";
  ConventionalCommitType2["STYLE"] = "style";
  ConventionalCommitType2["REFACTOR"] = "refactor";
  ConventionalCommitType2["PERF"] = "perf";
  ConventionalCommitType2["TEST"] = "test";
  ConventionalCommitType2["BUILD"] = "build";
  ConventionalCommitType2["CI"] = "ci";
  ConventionalCommitType2["CHORE"] = "chore";
  ConventionalCommitType2["REVERT"] = "revert";
  ConventionalCommitType2["BUMP"] = "bump";
  ConventionalCommitType2["RELEASE"] = "release";
})(ConventionalCommitType || (ConventionalCommitType = {}));
var ChangeCategory;
(function(ChangeCategory2) {
  ChangeCategory2["Added"] = "Added";
  ChangeCategory2["Changed"] = "Changed";
  ChangeCategory2["Deprecated"] = "Deprecated";
  ChangeCategory2["Fixed"] = "Fixed";
  ChangeCategory2["Removed"] = "Removed";
  ChangeCategory2["Security"] = "Security";
  ChangeCategory2["Uncategorized"] = "Uncategorized";
  ChangeCategory2["Excluded"] = "Excluded";
})(ChangeCategory || (ChangeCategory = {}));
var orderedChangeCategories = [
  ChangeCategory.Uncategorized,
  ChangeCategory.Added,
  ChangeCategory.Changed,
  ChangeCategory.Deprecated,
  ChangeCategory.Removed,
  ChangeCategory.Fixed,
  ChangeCategory.Security
];
var unreleased = "Unreleased";
var keywordsToIndicateExcluded = [
  "Bump main version to",
  "changelog",
  "cherry-pick",
  "cp-",
  "e2e",
  "flaky test",
  "INFRA-",
  "Merge pull request",
  "New Crowdin translations",
  "oidc",
  "sync stable into"
].map((word) => word.toLowerCase());
var CHANGELOG_VERB_TO_CATEGORY = {
  added: ChangeCategory.Added,
  adds: ChangeCategory.Added,
  add: ChangeCategory.Added,
  fixed: ChangeCategory.Fixed,
  fixes: ChangeCategory.Fixed,
  fix: ChangeCategory.Fixed,
  removed: ChangeCategory.Removed,
  removes: ChangeCategory.Removed,
  remove: ChangeCategory.Removed,
  deprecated: ChangeCategory.Deprecated,
  changed: ChangeCategory.Changed,
  change: ChangeCategory.Changed,
  updated: ChangeCategory.Changed,
  update: ChangeCategory.Changed,
  bumped: ChangeCategory.Changed,
  bump: ChangeCategory.Changed,
  improved: ChangeCategory.Changed,
  improves: ChangeCategory.Changed,
  improve: ChangeCategory.Changed,
  migrated: ChangeCategory.Changed,
  migrate: ChangeCategory.Changed
};

// node_modules/@metamask/auto-changelog/dist/changelog.js
var __classPrivateFieldSet = function(receiver, state, value, kind, f) {
  if (kind === "m") throw new TypeError("Private method is not writable");
  if (kind === "a" && !f) throw new TypeError("Private accessor was defined without a setter");
  if (typeof state === "function" ? receiver !== state || !f : !state.has(receiver)) throw new TypeError("Cannot write private member to an object whose class did not declare it");
  return kind === "a" ? f.call(receiver, value) : f ? f.value = value : state.set(receiver, value), value;
};
var __classPrivateFieldGet = function(receiver, state, kind, f) {
  if (kind === "a" && !f) throw new TypeError("Private accessor was defined without a getter");
  if (typeof state === "function" ? receiver !== state || !f : !state.has(receiver)) throw new TypeError("Cannot read private member from an object whose class did not declare it");
  return kind === "m" ? f : kind === "a" ? f.call(receiver) : f ? f.value : state.get(receiver);
};
var _Changelog_releases;
var _Changelog_changes;
var _Changelog_repoUrl;
var _Changelog_tagPrefix;
var _Changelog_formatter;
var _Changelog_packageRename;
function getKnownPropertyNames(object) {
  return Object.getOwnPropertyNames(object);
}
var changelogTitle = "# Changelog";
var changelogDescription = `All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).`;
function stringifyCategory(category, changes, repoUrl, useShortPrLink = false) {
  const categoryHeader = `### ${category}`;
  if (changes.length === 0) {
    return categoryHeader;
  }
  const changeDescriptions = changes.map(({ description, prNumbers }) => {
    const [firstLine, ...otherLines] = description.split("\n");
    const stringifiedPrLinks = prNumbers.map((prNumber) => useShortPrLink ? `#${prNumber}` : `[#${prNumber}](${repoUrl}/pull/${prNumber})`).join(", ");
    const parenthesizedPrLinks = stringifiedPrLinks.length > 0 ? ` (${stringifiedPrLinks})` : "";
    return [`- ${firstLine}${parenthesizedPrLinks}`, ...otherLines].join("\n");
  }).join("\n");
  return `${categoryHeader}
${changeDescriptions}`;
}
function stringifyRelease(version, categories, repoUrl, useShortPrLink = false, { date, status } = {}) {
  const releaseHeader = `## [${version}]${date ? ` - ${date}` : ""}${status ? ` [${status}]` : ""}`;
  const categorizedChanges = orderedChangeCategories.filter((category) => categories[category]).map((category) => {
    const changes = categories[category] ?? [];
    return stringifyCategory(category, changes, repoUrl, useShortPrLink);
  }).join("\n\n");
  if (categorizedChanges === "") {
    return releaseHeader;
  }
  return `${releaseHeader}
${categorizedChanges}`;
}
function stringifyReleases(releases, changes, repoUrl, useShortPrLink = false) {
  const stringifiedUnreleased = stringifyRelease(unreleased, changes[unreleased], repoUrl, useShortPrLink);
  const stringifiedReleases = releases.map(({ version, date, status }) => {
    const categories = changes[version];
    return stringifyRelease(version, categories, repoUrl, useShortPrLink, {
      ...date !== void 0 && { date },
      ...status !== void 0 && { status }
    });
  });
  return [stringifiedUnreleased, ...stringifiedReleases].join("\n\n");
}
function withTrailingSlash(url) {
  return url.endsWith("/") ? url : `${url}/`;
}
function getCompareUrl(repoUrl, firstRef, secondRef) {
  return `${withTrailingSlash(repoUrl)}compare/${firstRef}...${secondRef}`;
}
function getTagUrl(repoUrl, tag) {
  return `${withTrailingSlash(repoUrl)}releases/tag/${tag}`;
}
function stringifyLinkReferenceDefinitions(repoUrl, tagPrefix, releases, packageRename) {
  const unreleasedLinkReferenceDefinition = getUnreleasedLinkReferenceDefinition(repoUrl, tagPrefix, releases, packageRename);
  const releaseLinkReferenceDefinitions = getReleaseLinkReferenceDefinitions(repoUrl, tagPrefix, releases, packageRename).join("\n");
  return `${unreleasedLinkReferenceDefinition}
${releaseLinkReferenceDefinitions}${releases.length > 0 ? "\n" : ""}`;
}
function getUnreleasedLinkReferenceDefinition(repoUrl, tagPrefix, releases, packageRename) {
  const descendingSemverVersions = releases.map(({ version }) => version).sort((a, b) => {
    return import_semver.default.gt(a, b) ? -1 : 1;
  });
  const latestSemverVersion = descendingSemverVersions[0];
  const hasReleases = descendingSemverVersions.length > 0;
  const tagPrefixToCompare = (
    // oxlint-disable-next-line typescript/prefer-optional-chain -- Optional chaining makes two absent values compare equal.
    packageRename !== void 0 && packageRename.versionBeforeRename === latestSemverVersion ? packageRename.tagPrefixBeforeRename : tagPrefix
  );
  return `[${unreleased}]: ${hasReleases ? getCompareUrl(repoUrl, `${tagPrefixToCompare}${latestSemverVersion}`, "HEAD") : withTrailingSlash(repoUrl)}`;
}
function getReleaseLinkReferenceDefinitions(repoUrl, tagPrefix, releases, packageRename) {
  const chronologicalVersions = releases.map(({ version }) => version);
  let tagPrefixToCompare = tagPrefix;
  const releaseLinkReferenceDefinitions = releases.map(({ version }) => {
    let diffUrl;
    if (packageRename?.versionBeforeRename === version) {
      tagPrefixToCompare = packageRename.tagPrefixBeforeRename;
    }
    if (version === chronologicalVersions[chronologicalVersions.length - 1]) {
      diffUrl = getTagUrl(repoUrl, `${tagPrefixToCompare}${version}`);
    } else {
      const versionIndex = chronologicalVersions.indexOf(version);
      const previousVersion = chronologicalVersions.slice(versionIndex).find((releaseVersion) => {
        return import_semver.default.gt(version, releaseVersion);
      });
      if (previousVersion) {
        if (packageRename?.versionBeforeRename === previousVersion) {
          diffUrl = getCompareUrl(repoUrl, `${packageRename.tagPrefixBeforeRename}${previousVersion}`, `${tagPrefix}${version}`);
        } else {
          diffUrl = getCompareUrl(repoUrl, `${tagPrefixToCompare}${previousVersion}`, `${tagPrefixToCompare}${version}`);
        }
      } else {
        diffUrl = getTagUrl(repoUrl, `${tagPrefixToCompare}${version}`);
      }
    }
    return `[${version}]: ${diffUrl}`;
  });
  return releaseLinkReferenceDefinitions;
}
function formatDependencyBumpDescription(bump) {
  const prefix = bump.isBreaking ? "**BREAKING:** " : "";
  return `${prefix}Bump \`${bump.dependency}\` from \`${bump.oldVersion}\` to \`${bump.newVersion}\``;
}
var Changelog = class {
  /**
   * Construct an empty changelog.
   *
   * @param options - Changelog options.
   * @param options.repoUrl - The GitHub repository URL for the current project.
   * @param options.tagPrefix - The prefix used in tags before the version number.
   * @param options.formatter - A function that formats the changelog string.
   * @param options.packageRename - The package rename properties.
   * An optional, which is required only in case of package renamed.
   */
  constructor({ repoUrl, tagPrefix = "v", formatter = (changelog) => changelog, packageRename }) {
    _Changelog_releases.set(this, void 0);
    _Changelog_changes.set(this, void 0);
    _Changelog_repoUrl.set(this, void 0);
    _Changelog_tagPrefix.set(this, void 0);
    _Changelog_formatter.set(this, void 0);
    _Changelog_packageRename.set(this, void 0);
    __classPrivateFieldSet(this, _Changelog_releases, [], "f");
    __classPrivateFieldSet(this, _Changelog_changes, { [unreleased]: {} }, "f");
    __classPrivateFieldSet(this, _Changelog_repoUrl, repoUrl, "f");
    __classPrivateFieldSet(this, _Changelog_tagPrefix, tagPrefix, "f");
    __classPrivateFieldSet(this, _Changelog_formatter, formatter, "f");
    __classPrivateFieldSet(this, _Changelog_packageRename, packageRename, "f");
  }
  /**
   * Add a release to the changelog.
   *
   * @param options - Release options.
   * @param options.addToStart - Determines whether the change is added to the
   * top or bottom of the list of changes in this category. This defaults to
   * `true` because changes should be in reverse-chronological order. This
   * should be set to `false` when parsing a changelog top-to-bottom.
   * @param options.date - An ISO-8601 formatted date, representing the release
   * date.
   * @param options.status - The status of the release (e.g., 'WITHDRAWN',
   * 'DEPRECATED').
   * @param options.version - The version of the current release, which should
   * be a [SemVer](https://semver.org/spec/v2.0.0.html)-compatible version.
   */
  addRelease({ addToStart = true, date, status, version }) {
    if (!version) {
      throw new Error("Version required");
    } else if (import_semver.default.valid(version) === null) {
      throw new Error(`Not a valid semver version: '${version}'`);
    } else if (__classPrivateFieldGet(this, _Changelog_changes, "f")[version]) {
      throw new Error(`Release already exists: '${version}'`);
    }
    __classPrivateFieldGet(this, _Changelog_changes, "f")[version] = {};
    const newRelease = {
      version,
      ...date !== void 0 && { date },
      ...status !== void 0 && { status }
    };
    if (addToStart) {
      __classPrivateFieldGet(this, _Changelog_releases, "f").unshift(newRelease);
    } else {
      __classPrivateFieldGet(this, _Changelog_releases, "f").push(newRelease);
    }
  }
  /**
   * Add a change to the changelog.
   *
   * @param options - Change options.
   * @param options.addToStart - Determines whether the change is added to the
   * top or bottom of the list of changes in this category. This defaults to
   * `true` because changes should be in reverse-chronological order. This
   * should be set to `false` when parsing a changelog top-to-bottom.
   * @param options.category - The category of the change.
   * @param options.description - The description of the change. Optional if
   * `dependencyBump` is provided, in which case the description is
   * auto-generated.
   * @param options.version - The version this change was released in. If this
   * is not given, the change is assumed to be unreleased.
   * @param options.prNumbers - The pull request numbers associated with the
   * change.
   * @param options.dependencyBump - Structured dependency bump data. When
   * provided and no description is given, the description is auto-generated
   * from the bump data.
   */
  addChange(options) {
    const { addToStart = true, category, description, version, prNumbers = [] } = options;
    if (!category) {
      throw new Error("Category required");
    } else if (!orderedChangeCategories.includes(category)) {
      throw new Error(`Unrecognized category: '${category}'`);
    } else if (version !== void 0 && !__classPrivateFieldGet(this, _Changelog_changes, "f")[version]) {
      throw new Error(`Specified release version does not exist: '${version}'`);
    }
    const dependencyBump = "dependencyBump" in options ? options.dependencyBump : void 0;
    let effectiveDescription;
    if (dependencyBump !== void 0) {
      effectiveDescription = description ?? formatDependencyBumpDescription(dependencyBump);
    } else if (description) {
      effectiveDescription = description;
    } else {
      throw new Error("Description required");
    }
    const release = version ? __classPrivateFieldGet(this, _Changelog_changes, "f")[version] : __classPrivateFieldGet(this, _Changelog_changes, "f")[unreleased];
    const releaseCategory = release[category] ?? [];
    const change = {
      description: effectiveDescription,
      prNumbers
    };
    if (dependencyBump !== void 0) {
      change.dependencyBump = dependencyBump;
    }
    releaseCategory[addToStart ? "unshift" : "push"](change);
    release[category] = releaseCategory;
  }
  /**
   * Update an existing change entry in the changelog.
   *
   * @param options - Update options.
   * @param options.version - The version of the release containing the change.
   * If not given, the unreleased section is used.
   * @param options.category - The category of the change.
   * @param options.entryIndex - The index of the change within the category.
   * @param options.description - New description (optional).
   * @param options.prNumbers - New PR numbers (optional).
   * @param options.dependencyBump - New dependency bump data (optional).
   */
  updateChange(options) {
    const { version, category, entryIndex, prNumbers } = options;
    const release = version ? __classPrivateFieldGet(this, _Changelog_changes, "f")[version] : __classPrivateFieldGet(this, _Changelog_changes, "f")[unreleased];
    if (!release) {
      throw new Error(version ? `Could not find release: '${version}'` : `Could not find '${unreleased}' section`);
    }
    const releaseCategory = release[category];
    if (!releaseCategory) {
      throw new Error(`Could not find category '${category}' in release section '${version ?? unreleased}'`);
    }
    if (entryIndex < 0 || entryIndex >= releaseCategory.length) {
      throw new Error(`No change at index ${entryIndex} in category '${category}'`);
    }
    const change = releaseCategory[entryIndex];
    const description = "description" in options ? options.description : void 0;
    const dependencyBump = "dependencyBump" in options ? options.dependencyBump : void 0;
    if (description !== void 0) {
      change.description = description;
      if (dependencyBump !== void 0) {
        change.dependencyBump = dependencyBump;
      }
    } else if (dependencyBump !== void 0) {
      change.description = formatDependencyBumpDescription(dependencyBump);
      change.dependencyBump = dependencyBump;
    }
    if (prNumbers !== void 0) {
      change.prNumbers = prNumbers;
    }
  }
  /**
   * Migrate all unreleased changes to a release section.
   *
   * Changes are migrated in their existing categories, and placed above any
   * pre-existing changes in that category.
   *
   * @param version - The release version to migrate unreleased changes to.
   */
  migrateUnreleasedChangesToRelease(version) {
    const releaseChanges = __classPrivateFieldGet(this, _Changelog_changes, "f")[version];
    if (!releaseChanges) {
      throw new Error(`Specified release version does not exist: '${version}'`);
    }
    const unreleasedChanges = __classPrivateFieldGet(this, _Changelog_changes, "f")[unreleased];
    for (const category of getKnownPropertyNames(unreleasedChanges)) {
      if (releaseChanges[category]) {
        releaseChanges[category] = [
          ...unreleasedChanges[category] ?? [],
          ...releaseChanges[category] ?? []
        ];
      } else if (unreleasedChanges[category]) {
        releaseChanges[category] = unreleasedChanges[category];
      }
    }
    __classPrivateFieldGet(this, _Changelog_changes, "f")[unreleased] = {};
  }
  /**
   * Gets the metadata for all releases.
   *
   * @returns The metadata for each release.
   */
  getReleases() {
    return __classPrivateFieldGet(this, _Changelog_releases, "f");
  }
  /**
   * Gets the release of the given version.
   *
   * @param version - The version of the release to retrieve.
   * @returns The specified release, or undefined if no such release exists.
   */
  getRelease(version) {
    return this.getReleases().find(({ version: _version }) => _version === version);
  }
  /**
   * Gets the stringified release of the given version.
   * Throws an error if no such release exists.
   *
   * @param version - The version of the release to stringify.
   * @param useShortPrLink - Whether to use short PR links in the changelog entries.
   * @returns The stringified release, as it appears in the changelog.
   */
  getStringifiedRelease(version, useShortPrLink = false) {
    const release = this.getRelease(version);
    if (!release) {
      throw new Error(`Specified release version does not exist: '${version}'`);
    }
    const releaseChanges = this.getReleaseChanges(version);
    return stringifyRelease(version, releaseChanges, __classPrivateFieldGet(this, _Changelog_repoUrl, "f"), useShortPrLink, release);
  }
  /**
   * Gets the changes in the given release, organized by category.
   *
   * @param version - The version of the release being retrieved.
   * @returns The changes included in the given released.
   */
  getReleaseChanges(version) {
    return __classPrivateFieldGet(this, _Changelog_changes, "f")[version];
  }
  /**
   * Gets all changes that have not yet been released.
   *
   * @returns The changes that have not yet been released.
   */
  getUnreleasedChanges() {
    return __classPrivateFieldGet(this, _Changelog_changes, "f")[unreleased];
  }
  /**
   * The stringified changelog, formatted according to [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
   *
   * @param useShortPrLink - Whether to use short PR links in the changelog entries.
   * @returns The stringified changelog.
   */
  async toString(useShortPrLink = false) {
    const changelog = `${changelogTitle}
${changelogDescription}

${stringifyReleases(__classPrivateFieldGet(this, _Changelog_releases, "f"), __classPrivateFieldGet(this, _Changelog_changes, "f"), __classPrivateFieldGet(this, _Changelog_repoUrl, "f"), useShortPrLink)}

${stringifyLinkReferenceDefinitions(__classPrivateFieldGet(this, _Changelog_repoUrl, "f"), __classPrivateFieldGet(this, _Changelog_tagPrefix, "f"), __classPrivateFieldGet(this, _Changelog_releases, "f"), __classPrivateFieldGet(this, _Changelog_packageRename, "f"))}`;
    return await __classPrivateFieldGet(this, _Changelog_formatter, "f").call(this, changelog);
  }
};
_Changelog_releases = /* @__PURE__ */ new WeakMap(), _Changelog_changes = /* @__PURE__ */ new WeakMap(), _Changelog_repoUrl = /* @__PURE__ */ new WeakMap(), _Changelog_tagPrefix = /* @__PURE__ */ new WeakMap(), _Changelog_formatter = /* @__PURE__ */ new WeakMap(), _Changelog_packageRename = /* @__PURE__ */ new WeakMap();
var changelog_default = Changelog;

// node_modules/@metamask/auto-changelog/dist/parse-changelog.js
function parsePossibleDependencyBumpDescription(description) {
  const fullMatch = description.match(/^(\*\*BREAKING:\*\*\s+)?(?:Bump|Update|Upgrade) `([^`]+)` from `([^`]+)` to `([^`]+)`/u);
  if (fullMatch) {
    return {
      dependency: fullMatch[2],
      isBreaking: Boolean(fullMatch[1]),
      oldVersion: fullMatch[3],
      newVersion: fullMatch[4]
    };
  }
  const shortMatch = description.match(/^(\*\*BREAKING:\*\*\s+)?(?:Bump|Update|Upgrade) `([^`]+)` to `([^`]+)`/u);
  if (shortMatch) {
    return {
      dependency: shortMatch[2],
      isBreaking: Boolean(shortMatch[1]),
      oldVersion: "",
      newVersion: shortMatch[3]
    };
  }
  return void 0;
}
function truncated(line) {
  return line.length > 80 ? `${line.slice(0, 80)}...` : line;
}
function isValidChangeCategory(category) {
  return ChangeCategory[category] !== void 0;
}
function extractRepoName(repoUrl) {
  const match = repoUrl?.match(/github\.com\/[^/]+\/([^/]+)/u);
  return match ? match[1] : "";
}
function parseChangelog({ changelogContent, repoUrl, tagPrefix = "v", formatter, packageRename, shouldExtractPrLinks = false }) {
  const changelogLines = changelogContent.split(/(?:\r)?\n/u);
  const changelog = new changelog_default({
    repoUrl,
    tagPrefix,
    ...formatter !== void 0 && { formatter },
    ...packageRename !== void 0 && { packageRename }
  });
  const repoName = extractRepoName(repoUrl);
  const unreleasedHeaderIndex = changelogLines.indexOf(`## [${unreleased}]`);
  if (unreleasedHeaderIndex === -1) {
    throw new Error(`Failed to find ${unreleased} header`);
  }
  const unreleasedLinkReferenceDefinition = changelogLines.findIndex((line) => {
    return line.startsWith(`[${unreleased}]:`);
  });
  if (unreleasedLinkReferenceDefinition === -1) {
    throw new Error(`Failed to find ${unreleased} link reference definition`);
  }
  const contentfulChangelogLines = changelogLines.slice(unreleasedHeaderIndex + 1, unreleasedLinkReferenceDefinition);
  let mostRecentRelease;
  let mostRecentCategory;
  let currentChangeEntry;
  function finalizePreviousChange({ removeTrailingNewline = false } = {}) {
    if (!currentChangeEntry) {
      return;
    }
    if (!mostRecentCategory) {
      throw new Error("Cannot finalize change without most recent category.");
    }
    if (removeTrailingNewline && currentChangeEntry.endsWith("\n")) {
      currentChangeEntry = currentChangeEntry.slice(0, currentChangeEntry.length - 1);
    }
    const { description, prNumbers } = shouldExtractPrLinks ? extractPrLinks(currentChangeEntry, repoName) : {
      description: currentChangeEntry,
      prNumbers: []
    };
    const dependencyBump = parsePossibleDependencyBumpDescription(description);
    changelog.addChange({
      addToStart: false,
      category: mostRecentCategory,
      description,
      version: mostRecentRelease,
      prNumbers,
      ...dependencyBump !== void 0 && { dependencyBump }
    });
    currentChangeEntry = void 0;
  }
  for (const line of contentfulChangelogLines) {
    if (line.startsWith("## [")) {
      const results = line.match(/^## \[([^[\]]+)\](?: - (\d\d\d\d-\d\d-\d\d))?(?: \[(\w+)\])?/u);
      if (results === null) {
        throw new Error(`Malformed release header: '${truncated(line)}'`);
      }
      if (import_semver2.default.valid(results[1]) === null) {
        throw new Error(`Invalid SemVer version in release header: '${truncated(line)}'`);
      }
      finalizePreviousChange({
        removeTrailingNewline: true
      });
      mostRecentRelease = results[1];
      mostRecentCategory = void 0;
      const date = results[2];
      const status = results[3];
      changelog.addRelease({
        addToStart: false,
        date,
        status,
        version: mostRecentRelease
      });
    } else if (line.startsWith("### ")) {
      const results = line.match(/^### (\w+)$\b/u);
      if (results === null) {
        throw new Error(`Malformed category header: '${truncated(line)}'`);
      }
      const isFirstCategory = mostRecentCategory === null;
      finalizePreviousChange({
        removeTrailingNewline: !isFirstCategory
      });
      if (!isValidChangeCategory(results[1])) {
        throw new Error(`Invalid change category: '${results[1]}'`);
      }
      mostRecentCategory = results[1];
    } else if (line.startsWith("- ")) {
      if (!mostRecentCategory) {
        throw new Error(`Category missing for change: '${truncated(line)}'`);
      }
      const description = line.slice(2);
      finalizePreviousChange();
      currentChangeEntry = description;
    } else if (currentChangeEntry) {
      currentChangeEntry += `
${line}`;
    } else if (line === "") {
      continue;
    } else {
      throw new Error(`Unrecognized line: '${truncated(line)}'`);
    }
  }
  finalizePreviousChange({ removeTrailingNewline: true });
  return changelog;
}
function extractPrLinks(changeEntry, repoName) {
  const lines = changeEntry.split("\n");
  const prNumbers = [];
  let firstLine = lines[0];
  const longLinkGroup = `\\(\\s*(?:\\[#\\d+\\]\\([^)]*${repoName}[^)]*\\)\\s*,?\\s*)+\\)`;
  const longGroupMatchPattern = new RegExp(
    // Match the canonical form `(... , ...)` and the legacy form where
    // multiple parenthesized groups are written next to each other separated
    // by commas: `([#123](...)), ([#456](...))`. In the legacy form the
    // inter-group `, ` must be consumed so it isn't left behind in the
    // description after replacement.
    `\\s+${longLinkGroup}(?:\\s*,\\s*${longLinkGroup})*`,
    "gu"
  );
  const longMatchPattern = new RegExp(
    // Example of long match: "[#123](...)"
    `\\[#(\\d+)\\]\\([^)]*${repoName}[^)]*\\)`,
    "gu"
  );
  const longGroupMatches = [...firstLine.matchAll(longGroupMatchPattern)];
  for (const longGroupMatch of longGroupMatches) {
    const group = longGroupMatch[0];
    const longMatches = [...group.matchAll(longMatchPattern)];
    for (const match of longMatches) {
      prNumbers.push(match[1]);
    }
  }
  firstLine = firstLine.replace(longGroupMatchPattern, "");
  const shortGroupMatchPattern = /\s+(\(#\d+(?:\s*,\s*#\d+)*\)\s*,?\s*)+/gu;
  const shortMatchPattern = /#(\d+)/gu;
  const shortGroupMatches = [...firstLine.matchAll(shortGroupMatchPattern)];
  for (const shortGroupMatch of shortGroupMatches) {
    const group = shortGroupMatch[0];
    const shortMatches = [...group.matchAll(shortMatchPattern)];
    for (const match of shortMatches) {
      prNumbers.push(match[1]);
    }
  }
  firstLine = firstLine.replace(shortGroupMatchPattern, "");
  const cleanedLines = [firstLine.trim(), ...lines.slice(1)];
  const cleanedDescription = cleanedLines.join("\n");
  return {
    description: cleanedDescription.trim(),
    prNumbers: [...new Set(prNumbers)]
  };
}

// scripts/check-changelog.ts
var import_semver4 = __toESM(require_semver2(), 1);
import { execFileSync } from "node:child_process";
import { randomUUID } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";

// scripts/package-json-diff.ts
var import_semver3 = __toESM(require_semver2(), 1);
var NO_CHANGES = {
  hasChanges: false,
  isVersionOnly: false,
  isDevDependencyOnly: false,
  isVersionAndDevDependencyOnly: false,
  isVersionDowngrade: false,
  newVersion: void 0
};
function getDevDependencyLines(diffOutput, nonVersionLines) {
  const allLines = diffOutput.split("\n");
  const devDependencyLines = [];
  let devDependencySectionStart;
  let devDependencySectionEnd;
  for (let i = 0; i < allLines.length; i++) {
    const line = allLines[i];
    if (line.includes('"devDependencies":')) {
      devDependencySectionStart = i;
    } else if (devDependencySectionStart && /^[ +-]\s*\}/u.test(line)) {
      devDependencySectionEnd = i;
      break;
    }
  }
  if (devDependencySectionStart === void 0 || devDependencySectionEnd === void 0) {
    return [];
  }
  for (const changeLine of nonVersionLines) {
    const lineIndex = allLines.findIndex((line) => line === changeLine);
    if (lineIndex !== -1 && lineIndex >= devDependencySectionStart && lineIndex <= devDependencySectionEnd) {
      devDependencyLines.push(changeLine);
    }
  }
  return devDependencyLines;
}
function isVersionDowngrade(oldVersion, newVersion) {
  if (!import_semver3.default.valid(oldVersion) || !import_semver3.default.valid(newVersion)) {
    return false;
  }
  return import_semver3.default.lt(newVersion, oldVersion);
}
function analyzePackageJsonDiff(diffOutput) {
  if (!diffOutput) {
    return { ...NO_CHANGES };
  }
  const lines = diffOutput.split("\n").filter((line) => line.startsWith("+") || line.startsWith("-")).filter((line) => !line.startsWith("+++") && !line.startsWith("---"));
  if (lines.length === 0) {
    return { ...NO_CHANGES };
  }
  const versionLines = [];
  const nonVersionLines = [];
  let oldVersion;
  let newVersion;
  for (const line of lines) {
    const match = line.match(/^([+-])\s*"version":\s*"([^"]+)"\s*,?\s*$/u);
    if (match) {
      versionLines.push({
        type: match[1] === "+" ? "added" : "removed",
        version: match[2]
      });
    } else {
      nonVersionLines.push(line);
    }
  }
  if (versionLines[0]?.type === "removed" && versionLines[1]?.type === "added") {
    oldVersion = versionLines[0].version;
    newVersion = versionLines[1].version;
  }
  const isDowngrade = oldVersion && newVersion ? isVersionDowngrade(oldVersion, newVersion) : false;
  if (nonVersionLines.length === 0) {
    return {
      hasChanges: true,
      isVersionOnly: true,
      isDevDependencyOnly: false,
      isVersionAndDevDependencyOnly: false,
      isVersionDowngrade: isDowngrade,
      newVersion
    };
  }
  const devDependencyLines = getDevDependencyLines(diffOutput, nonVersionLines);
  const allNonVersionLinesAreDevDeps = devDependencyLines.length === nonVersionLines.length;
  return {
    hasChanges: true,
    isVersionOnly: false,
    isDevDependencyOnly: !newVersion && allNonVersionLinesAreDevDeps,
    isVersionAndDevDependencyOnly: newVersion !== void 0 && allNonVersionLinesAreDevDeps,
    isVersionDowngrade: isDowngrade,
    newVersion
  };
}

// scripts/check-changelog.ts
var stopToken;
function stopCommands() {
  stopToken = randomUUID();
  console.log(`::stop-commands::${stopToken}`);
}
function resumeCommands() {
  if (stopToken !== void 0) {
    console.log(`::${stopToken}::`);
    stopToken = void 0;
  }
}
function logWarning(message) {
  const stopped = stopToken !== void 0;
  resumeCommands();
  const escaped = message.replace(/%/gu, "%25").replace(/\r/gu, "%0D").replace(/\n/gu, "%0A");
  console.log(`::warning::${escaped}`);
  if (stopped) {
    stopCommands();
  }
}
function logError(message) {
  console.log(`\x1B[31m${message}\x1B[0m`);
}
function errorMessage(error) {
  return error instanceof Error ? error.message : String(error);
}
function git(repoPath, args) {
  return execFileSync("git", args, {
    cwd: repoPath,
    encoding: "utf8",
    maxBuffer: 256 * 1024 * 1024,
    stdio: ["ignore", "pipe", "pipe"]
  }).replace(/\n$/u, "");
}
async function readRepoFile(repoPath, filePath) {
  const fullPath = path.join(repoPath, filePath);
  const realPath = await fs.realpath(fullPath);
  if (realPath !== path.join(await fs.realpath(repoPath), filePath)) {
    throw new Error(`${filePath} is a symbolic link or is under one; refusing to read it`);
  }
  return fs.readFile(realPath, "utf-8");
}
async function getWorkspacePatterns(repoPath) {
  const content = await readRepoFile(repoPath, "package.json");
  const packageJson = JSON.parse(content);
  if (!Array.isArray(packageJson.workspaces)) {
    return [];
  }
  return packageJson.workspaces;
}
function getPackageInfo(filePath, workspacePatterns) {
  for (const pattern of workspacePatterns) {
    const wildcardIndex = pattern.indexOf("*");
    if (wildcardIndex === -1) {
      continue;
    }
    const baseDir = pattern.substring(0, wildcardIndex);
    if (filePath.startsWith(baseDir)) {
      const remainingPath = filePath.substring(baseDir.length);
      const nextSlashIndex = remainingPath.indexOf("/");
      if (nextSlashIndex !== -1) {
        return { base: baseDir, package: remainingPath.substring(0, nextSlashIndex) };
      }
    }
  }
  return null;
}
function getChangedFiles(repoPath, baseRef) {
  try {
    git(repoPath, ["fetch", "origin", baseRef]);
  } catch (error) {
    try {
      git(repoPath, ["rev-parse", "--verify", "--quiet", `refs/remotes/origin/${baseRef}`]);
      logWarning(
        `Could not fetch ${baseRef}; using origin/${baseRef} from the checkout. ${errorMessage(error)}`
      );
    } catch {
      logError(`Failed to get changed files: ${errorMessage(error)}`);
      throw error;
    }
  }
  try {
    return git(repoPath, [
      "-c",
      "core.quotePath=false",
      "diff",
      "-z",
      "--name-only",
      `origin/${baseRef}...HEAD`
    ]).split("\0").filter(Boolean);
  } catch (error) {
    logError(`Failed to get changed files: ${errorMessage(error)}`);
    throw error;
  }
}
function analyzePackageJsonChanges(repoPath, filePath, baseRef) {
  try {
    const diff = git(repoPath, ["diff", "-U9999", `origin/${baseRef}...HEAD`, "--", filePath]);
    return analyzePackageJsonDiff(diff);
  } catch (error) {
    logError(`Failed to analyze package.json changes in ${filePath}: ${errorMessage(error)}`);
    return analyzePackageJsonDiff("");
  }
}
function isDeletedSinceBase(repoPath, filePath, baseRef) {
  const output = git(repoPath, [
    "diff",
    "--no-renames",
    "--name-only",
    "--diff-filter=D",
    `origin/${baseRef}...HEAD`,
    "--",
    filePath
  ]);
  return output !== "";
}
async function getPackageVisibility(repoPath, packageJsonPath) {
  try {
    const content = await readRepoFile(repoPath, packageJsonPath);
    return JSON.parse(content).private === true ? "private" : "public";
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      return "missing";
    }
    logError(`Failed to check if package is private: ${errorMessage(error)}`);
    return "public";
  }
}
async function checkChangelogFile({
  repoPath,
  changelogPath,
  prNumber,
  packageVersion
}) {
  try {
    const changelogContent = await readRepoFile(repoPath, changelogPath);
    if (!changelogContent) {
      throw new Error("CHANGELOG.md is empty or missing");
    }
    const changelog = parseChangelog({
      changelogContent,
      repoUrl: "",
      shouldExtractPrLinks: true
    });
    let releaseSection = "Unreleased";
    if (packageVersion) {
      if (!import_semver4.default.valid(packageVersion)) {
        throw new Error(
          `The new version '${packageVersion}' in ${path.join(path.dirname(changelogPath), "package.json")} is not valid semver, so its changelog section can't be checked. If the changelog is up to date, you can bypass this check by adding the 'no-changelog' label to the PR.`
        );
      }
      const versionChanges = changelog.getReleaseChanges(packageVersion);
      if (versionChanges && Object.keys(versionChanges).length > 0) {
        releaseSection = packageVersion;
      } else {
        throw new Error(
          `Could not find section for version '${packageVersion}' in the changelog ("${changelogPath}").`
        );
      }
    }
    const changes = changelog.getReleaseChanges(releaseSection);
    const linked = Object.values(changes).flat().some((entry) => entry.prNumbers.includes(prNumber));
    if (!linked) {
      throw new Error(
        `There are changes made to this package that may not be reflected in the changelog ("${changelogPath}"). If the changes you've introduced are user-facing, please document them under the "${releaseSection}" section, making sure to link the entries to the current PR. If the changelog is up to date, you can bypass this check by adding the 'no-changelog' label to the PR.`
      );
    }
  } catch (error) {
    if (error instanceof Error && "code" in error && error.code === "ENOENT") {
      throw new Error(`CHANGELOG.md not found at ${changelogPath}`);
    }
    throw error;
  }
}
async function getChangedPackages(files, workspacePatterns, repoPath, baseRef) {
  const changedPackages = /* @__PURE__ */ new Map();
  const visibilityCache = /* @__PURE__ */ new Map();
  for (const file of files) {
    if (file.startsWith(".github/workflows/")) {
      continue;
    }
    const packageInfo = getPackageInfo(file, workspacePatterns);
    if (!packageInfo) {
      continue;
    }
    const packageDir = path.join(packageInfo.base, packageInfo.package);
    let visibility = visibilityCache.get(packageDir);
    if (visibility === void 0) {
      const packageJsonPath = path.join(packageDir, "package.json");
      visibility = await getPackageVisibility(repoPath, packageJsonPath);
      if (visibility === "missing") {
        if (!isDeletedSinceBase(repoPath, packageJsonPath, baseRef)) {
          throw new Error(
            `${file} maps to ${packageDir}, which has no package.json at the pull request head or the merge base. Only workspace patterns of the form <root>/* are supported.`
          );
        }
        console.log(`Skipping ${packageDir}: its package.json was deleted`);
      }
      visibilityCache.set(packageDir, visibility);
    }
    if (visibility !== "public") {
      continue;
    }
    if (file.match(/\.(test|spec)\./u) || file.includes("__tests__/") || file.includes("/docs/") || file.endsWith("CHANGELOG.md")) {
      continue;
    }
    let newVersion;
    if (file === path.join(packageDir, "package.json")) {
      const changes = analyzePackageJsonChanges(repoPath, file, baseRef);
      if (!changes.hasChanges) {
        continue;
      }
      if (changes.isVersionOnly) {
        console.log(`Skipping package.json in ${packageDir} as it only contains version changes`);
        continue;
      }
      if (changes.isVersionDowngrade) {
        console.log(
          `Skipping package.json in ${packageDir} as it contains a version downgrade (revert)`
        );
        continue;
      }
      if (changes.isDevDependencyOnly) {
        console.log(
          `Skipping package.json in ${packageDir} as it only contains dev dependency changes`
        );
        continue;
      }
      if (changes.isVersionAndDevDependencyOnly) {
        console.log(
          `Skipping package.json in ${packageDir} as it only contains version and dev dependency changes`
        );
        continue;
      }
      newVersion = changes.newVersion;
    }
    const existing = changedPackages.get(packageDir);
    changedPackages.set(packageDir, {
      ...packageInfo,
      newVersion: existing?.newVersion ?? newVersion
    });
  }
  return Array.from(changedPackages.values());
}
async function main(argv) {
  const [repoPath, baseRef, prNumber] = argv;
  if (!repoPath || !baseRef || !prNumber) {
    throw new Error("Usage: node check-changelog.ts <repo-path> <base-branch> <pr-number>");
  }
  const fullRepoPath = path.resolve(process.cwd(), repoPath);
  try {
    await fs.access(fullRepoPath);
  } catch {
    throw new Error(`Repository path not found: ${fullRepoPath}`);
  }
  const workspacePatterns = await getWorkspacePatterns(fullRepoPath);
  if (workspacePatterns.length === 0) {
    console.log("Running in single-repo mode - checking changelog for the entire repository...");
    await checkChangelogFile({ repoPath: fullRepoPath, changelogPath: "CHANGELOG.md", prNumber });
    console.log("CHANGELOG.md has been correctly updated.");
    return;
  }
  console.log("Running in monorepo mode - checking changelogs for changed packages...");
  const changedFiles = getChangedFiles(fullRepoPath, baseRef);
  if (changedFiles.length === 0) {
    console.log("No changed files found. Exiting successfully.");
    return;
  }
  const changedPackages = await getChangedPackages(
    changedFiles,
    workspacePatterns,
    fullRepoPath,
    baseRef
  );
  if (changedPackages.length === 0) {
    console.log("No package code changes detected that would require changelog updates.");
    return;
  }
  const results = await Promise.all(
    changedPackages.map(async (pkg) => {
      const packageDir = path.join(pkg.base, pkg.package);
      const changelogPath = path.join(packageDir, "CHANGELOG.md");
      try {
        await checkChangelogFile({
          repoPath: fullRepoPath,
          changelogPath,
          prNumber,
          packageVersion: pkg.newVersion ?? null
        });
        console.log(`CHANGELOG.md for ${packageDir} has been correctly updated.`);
        return true;
      } catch (error) {
        logError(`Changelog check failed for package ${packageDir}: ${errorMessage(error)}`);
        return false;
      }
    })
  );
  if (results.includes(false)) {
    throw new Error("One or more changelog checks failed");
  }
}
if (import.meta.main) {
  stopCommands();
  main(process.argv.slice(2)).catch((error) => {
    logError(errorMessage(error));
    process.exitCode = 1;
  }).finally(resumeCommands);
}
export {
  getPackageInfo
};
