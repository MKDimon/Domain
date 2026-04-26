import 'dart:convert';
import 'package:lua_dardo/lua.dart';

const _maxBlocks = 500;
const _maxLogEntries = 200;
const _maxLogLineLength = 1000;
const _maxTableDepth = 20;
const _maxHttpRequests = 10;

class ScriptBlock {
  final String type;
  final Map<String, dynamic> props;
  ScriptBlock(this.type, [this.props = const {}]);
  Map<String, dynamic> toMap() => {'type': type, ...props};
}

class SandboxContext {
  final int sectionId;
  final int userId;
  final String userName;
  final bool isLoggedIn;
  final String communityName;
  final int communityId;
  final String pageTitle;
  final bool allowExternalAccess;

  const SandboxContext({
    required this.sectionId,
    this.userId = 0,
    this.userName = '',
    this.isLoggedIn = false,
    this.communityName = '',
    this.communityId = 0,
    this.pageTitle = '',
    this.allowExternalAccess = false,
  });
}

class SandboxResult {
  final bool success;
  final String? error;
  final List<ScriptBlock> blocks;
  final List<String> logs;

  const SandboxResult({
    required this.success,
    this.error,
    this.blocks = const [],
    this.logs = const [],
  });
}

typedef YieldHandler = Future<dynamic> Function(Map<String, dynamic> request);

class LuaSandbox {
  LuaState? _ls;
  final List<ScriptBlock> _blocks = [];
  final List<String> _logs = [];
  int _httpRequestCount = 0;

  List<ScriptBlock>? _columnStack;
  int _currentColIndex = -1;
  final Map<int, int> _callbacks = {};
  int _callbackCounter = 0;

  List<ScriptBlock> get _outputTarget {
    if (_columnStack != null && _currentColIndex >= 0 && _currentColIndex < _columnStack!.length) {
      return [_columnStack![_currentColIndex]];
    }
    return _blocks;
  }

  void _addBlock(ScriptBlock block) {
    final target = (_columnStack != null && _currentColIndex >= 0 && _currentColIndex < (_columnStack?.length ?? 0))
        ? _columnStack![_currentColIndex]
        : null;

    if (target != null) {
      // Column mode: target is a single ScriptBlock of type 'column_items'
      // We accumulate into the _columnBlocks map
      _columnBlocksMap[_currentColIndex] ??= [];
      if (_columnBlocksMap[_currentColIndex]!.length < _maxBlocks) {
        _columnBlocksMap[_currentColIndex]!.add(block);
      }
    } else {
      if (_blocks.length < _maxBlocks) _blocks.add(block);
    }
  }

  final Map<int, List<ScriptBlock>> _columnBlocksMap = {};

  void destroy() {
    _ls = null;
    _blocks.clear();
    _logs.clear();
    _callbacks.clear();
    _columnStack = null;
    _columnBlocksMap.clear();
    _currentColIndex = -1;
  }

  LuaState _createState(SandboxContext ctx) {
    final ls = LuaState.newState();
    ls.openLibs();

    // Remove dangerous globals
    for (final name in [
      'io', 'os', 'debug', 'loadfile', 'dofile', 'require', 'load',
      'rawget', 'rawset', 'rawequal', 'rawlen',
      'collectgarbage', 'newproxy',
      'package', 'setmetatable', 'getmetatable', 'coroutine',
      '_G',
    ]) {
      ls.pushNil();
      ls.setGlobal(name);
    }

    _registerPrint(ls);
    _registerUiApi(ls, ctx);
    _registerJsonApi(ls);
    _registerUserApi(ls, ctx);
    _registerPageApi(ls, ctx);

    return ls;
  }

  void _registerPrint(LuaState ls) {
    ls.pushDartFunction((LuaState ls) {
      if (_logs.length >= _maxLogEntries) return 0;
      final n = ls.getTop();
      final parts = <String>[];
      for (var i = 1; i <= n; i++) {
        var s = ls.toStr(i) ?? 'nil';
        if (s.length > _maxLogLineLength) s = '${s.substring(0, _maxLogLineLength)}...';
        parts.add(s);
      }
      _logs.add(parts.join('\t'));
      return 0;
    });
    ls.setGlobal('print');
  }

  void _setField(LuaState ls, String name, int Function(LuaState) fn) {
    ls.pushDartFunction(fn);
    ls.setField(-2, name);
  }

  void _registerUiApi(LuaState ls, SandboxContext ctx) {
    ls.newTable();

    _setField(ls, 'text', (ls) {
      final text = ls.checkString(1) ?? '';
      _addBlock(ScriptBlock('paragraph', {'text': text}));
      return 0;
    });

    _setField(ls, 'heading', (ls) {
      final text = ls.checkString(1) ?? '';
      final level = ls.isNumber(2) ? ls.toNumber(2)?.toInt() ?? 2 : 2;
      _addBlock(ScriptBlock('heading', {'text': text, 'level': level.clamp(1, 6)}));
      return 0;
    });

    _setField(ls, 'callout', (ls) {
      final style = ls.checkString(1) ?? 'info';
      final text = ls.checkString(2) ?? '';
      const valid = ['info', 'warning', 'success', 'error', 'tip'];
      _addBlock(ScriptBlock('callout', {'style': valid.contains(style) ? style : 'info', 'text': text}));
      return 0;
    });

    _setField(ls, 'code', (ls) {
      final language = ls.checkString(1) ?? '';
      final code = ls.checkString(2) ?? '';
      _addBlock(ScriptBlock('code', {'language': language, 'content': code}));
      return 0;
    });

    _setField(ls, 'divider', (ls) {
      _addBlock(ScriptBlock('divider'));
      return 0;
    });

    _setField(ls, 'quote', (ls) {
      final text = ls.checkString(1) ?? '';
      _addBlock(ScriptBlock('quote', {'text': text}));
      return 0;
    });

    _setField(ls, 'list', (ls) {
      final items = _readLuaValue(ls, 1);
      final ordered = ls.toBoolean(2);
      final list = items is List ? items.map((e) => e.toString()).toList() : <String>[];
      _addBlock(ScriptBlock('list', {'items': list, 'style': ordered ? 'ordered' : 'unordered'}));
      return 0;
    });

    _setField(ls, 'table', (ls) {
      final headers = _readLuaValue(ls, 1);
      final rows = _readLuaValue(ls, 2);
      _addBlock(ScriptBlock('table', {
        'headers': headers is List ? headers : [],
        'rows': rows is List ? rows : [],
      }));
      return 0;
    });

    _setField(ls, 'image', (ls) {
      var url = ls.checkString(1) ?? '';
      final alt = ls.isString(2) ? (ls.toStr(2) ?? '') : '';
      if (!url.startsWith('https://')) url = '';
      _addBlock(ScriptBlock('image', {'url': url, 'caption': alt}));
      return 0;
    });

    _setField(ls, 'accordion', (ls) {
      final items = _readLuaValue(ls, 1);
      _addBlock(ScriptBlock('accordion', {'items': items is List ? items : []}));
      return 0;
    });

    _setField(ls, 'columns', (ls) {
      final n = ls.isNumber(1) ? (ls.toNumber(1)?.toInt() ?? 2).clamp(1, 4) : 2;
      _columnStack = List.generate(n, (_) => ScriptBlock('_col_placeholder'));
      _columnBlocksMap.clear();
      _currentColIndex = -1;
      return 0;
    });

    _setField(ls, 'col', (ls) {
      if (_columnStack != null) {
        _currentColIndex++;
        if (_currentColIndex >= _columnStack!.length) {
          _currentColIndex = _columnStack!.length - 1;
        }
      }
      return 0;
    });

    _setField(ls, 'end_columns', (ls) {
      if (_columnStack != null) {
        final columns = <Map<String, dynamic>>[];
        for (var i = 0; i < _columnStack!.length; i++) {
          columns.add({'blocks': (_columnBlocksMap[i] ?? []).map((b) => b.toMap()).toList()});
        }
        _blocks.add(ScriptBlock('columns', {'columns': columns}));
        _columnStack = null;
        _columnBlocksMap.clear();
        _currentColIndex = -1;
      }
      return 0;
    });

    _setField(ls, 'button', (ls) {
      final label = ls.checkString(1) ?? '';
      final cbId = _callbackCounter++;
      if (ls.isFunction(2)) {
        ls.pushValue(2);
        final ref = ls.ref(luaRegistryIndex);
        _callbacks[cbId] = ref;
      }
      _addBlock(ScriptBlock('_button', {'label': label, 'callbackId': cbId}));
      return 0;
    });

    _setField(ls, 'input', (ls) {
      final placeholder = ls.isString(1) ? (ls.toStr(1) ?? '') : '';
      final cbId = _callbackCounter++;
      if (ls.isFunction(2)) {
        ls.pushValue(2);
        final ref = ls.ref(luaRegistryIndex);
        _callbacks[cbId] = ref;
      }
      _addBlock(ScriptBlock('_input', {'placeholder': placeholder, 'callbackId': cbId}));
      return 0;
    });

    _setField(ls, 'clear', (ls) {
      _blocks.clear();
      _columnStack = null;
      _columnBlocksMap.clear();
      _currentColIndex = -1;
      return 0;
    });

    ls.setGlobal('ui');
  }

  void _registerJsonApi(LuaState ls) {
    ls.newTable();
    _setField(ls, 'parse', (ls) {
      final str = ls.checkString(1) ?? '';
      try {
        _pushDartValue(ls, jsonDecode(str));
        return 1;
      } catch (_) {
        ls.pushNil();
        ls.pushString('Invalid JSON');
        return 2;
      }
    });
    _setField(ls, 'encode', (ls) {
      try {
        ls.pushString(jsonEncode(_readLuaValue(ls, 1)));
        return 1;
      } catch (_) {
        ls.pushNil();
        return 1;
      }
    });
    ls.setGlobal('json');
  }

  void _registerUserApi(LuaState ls, SandboxContext ctx) {
    ls.newTable();
    _setField(ls, 'name', (ls) { ls.pushString(ctx.userName); return 1; });
    _setField(ls, 'id', (ls) { ls.pushNumber(ctx.userId.toDouble()); return 1; });
    _setField(ls, 'is_logged_in', (ls) { ls.pushBoolean(ctx.isLoggedIn); return 1; });
    ls.setGlobal('user');
  }

  void _registerPageApi(LuaState ls, SandboxContext ctx) {
    ls.newTable();
    _setField(ls, 'community_name', (ls) { ls.pushString(ctx.communityName); return 1; });
    _setField(ls, 'community_id', (ls) { ls.pushNumber(ctx.communityId.toDouble()); return 1; });
    _setField(ls, 'title', (ls) { ls.pushString(ctx.pageTitle); return 1; });
    ls.setGlobal('page');
  }

  void _pushDartValue(LuaState ls, dynamic value) {
    if (value == null) {
      ls.pushNil();
    } else if (value is bool) {
      ls.pushBoolean(value);
    } else if (value is num) {
      ls.pushNumber(value.toDouble());
    } else if (value is String) {
      ls.pushString(value);
    } else if (value is List) {
      ls.newTable();
      for (var i = 0; i < value.length; i++) {
        _pushDartValue(ls, value[i]);
        ls.rawSetI(-2, i + 1);
      }
    } else if (value is Map) {
      ls.newTable();
      for (final entry in value.entries) {
        ls.pushString(entry.key.toString());
        _pushDartValue(ls, entry.value);
        ls.setTable(-3);
      }
    }
  }

  dynamic _readLuaValue(LuaState ls, int index, [int depth = 0]) {
    if (depth > _maxTableDepth) return null;
    if (ls.isNil(index)) return null;
    if (ls.isBoolean(index)) return ls.toBoolean(index);
    if (ls.isNumber(index)) return ls.toNumber(index);
    if (ls.isString(index)) return ls.toStr(index);
    if (ls.isTable(index)) {
      final result = <String, dynamic>{};
      var isArray = true;
      var maxIdx = 0;

      ls.pushNil();
      while (ls.next(index < 0 ? index - 1 : index)) {
        if (ls.isNumber(-2)) {
          final n = ls.toNumber(-2)!;
          if (n == n.toInt() && n > 0) {
            maxIdx = n.toInt() > maxIdx ? n.toInt() : maxIdx;
          } else {
            isArray = false;
          }
        } else {
          isArray = false;
        }
        ls.pop(1);
      }

      if (isArray && maxIdx > 0) {
        final arr = <dynamic>[];
        for (var i = 1; i <= maxIdx; i++) {
          ls.rawGetI(index, i);
          arr.add(_readLuaValue(ls, -1, depth + 1));
          ls.pop(1);
        }
        return arr;
      }

      ls.pushNil();
      while (ls.next(index < 0 ? index - 1 : index)) {
        final key = _readLuaValue(ls, -2, depth + 1)?.toString();
        if (key != null) {
          result[key] = _readLuaValue(ls, -1, depth + 1);
        }
        ls.pop(1);
      }
      return result;
    }
    return null;
  }

  SandboxResult execute(String code, SandboxContext ctx) {
    destroy();
    _blocks.clear();
    _logs.clear();
    _httpRequestCount = 0;
    _callbackCounter = 0;
    _callbacks.clear();

    try {
      _ls = _createState(ctx);
      final loadResult = _ls!.loadString(code);
      if (loadResult != ThreadStatus.luaOk) {
        final err = _ls!.toStr(-1) ?? 'Failed to load script';
        return SandboxResult(success: false, error: err, logs: List.from(_logs));
      }

      final callResult = _ls!.pCall(0, 0, 0);
      if (callResult != ThreadStatus.luaOk) {
        final err = _ls!.toStr(-1) ?? 'Script error';
        return SandboxResult(success: false, error: err, blocks: List.from(_blocks), logs: List.from(_logs));
      }

      return SandboxResult(success: true, blocks: List.from(_blocks), logs: List.from(_logs));
    } catch (e) {
      return SandboxResult(success: false, error: e.toString(), blocks: List.from(_blocks), logs: List.from(_logs));
    }
  }

  SandboxResult invokeCallback(int callbackId, [String? inputValue]) {
    if (_ls == null) return const SandboxResult(success: false, error: 'No active state');
    final ref = _callbacks[callbackId];
    if (ref == null) return const SandboxResult(success: false, error: 'Callback not found');

    _columnStack = null;
    _columnBlocksMap.clear();
    _currentColIndex = -1;

    try {
      _ls!.rawGetI(luaRegistryIndex, ref);
      if (!_ls!.isFunction(-1)) {
        _ls!.pop(1);
        return const SandboxResult(success: false, error: 'Callback is not a function');
      }

      var nArgs = 0;
      if (inputValue != null) {
        _ls!.pushString(inputValue);
        nArgs = 1;
      }

      final result = _ls!.pCall(nArgs, 0, 0);
      if (result != ThreadStatus.luaOk) {
        final err = _ls!.toStr(-1) ?? 'Callback error';
        return SandboxResult(success: false, error: err, blocks: List.from(_blocks), logs: List.from(_logs));
      }

      return SandboxResult(success: true, blocks: List.from(_blocks), logs: List.from(_logs));
    } catch (e) {
      return SandboxResult(success: false, error: e.toString());
    }
  }
}
