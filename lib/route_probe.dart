import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

/// Injected before Google's own JS runs. Copies the body of any route-looking
/// XHR/fetch response and forwards it to Flutter (queued until the bridge is ready).
const _interceptorJs = r'''
(function () {
  const MATCH = /\/maps\/(preview|rpc)\/|\/maps\/dir|directions/i;
  const queue = [];
  let ready = false;

  function emit(url, body) {
    if (ready && window.flutter_inappwebview) {
      window.flutter_inappwebview.callHandler('captured', String(url), String(body));
    } else {
      queue.push([url, body]);
    }
  }
  window.addEventListener('flutterInAppWebViewPlatformReady', function () {
    ready = true;
    while (queue.length) { const q = queue.shift(); emit(q[0], q[1]); }
  });

  const oOpen = XMLHttpRequest.prototype.open;
  const oSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (m, u) {
    this.__url = u;
    return oOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function () {
    this.addEventListener('load', () => {
      try {
        if (MATCH.test(this.__url)) emit(this.__url, this.responseText);
      } catch (e) {}
    });
    return oSend.apply(this, arguments);
  };

  const oFetch = window.fetch;
  window.fetch = function (input) {
    return oFetch.apply(this, arguments).then((res) => {
      try {
        const u = typeof input === 'string' ? input : input.url;
        if (MATCH.test(u)) res.clone().text().then((t) => emit(u, t));
      } catch (e) {}
      return res;
    });
  };
})();
''';

const _desktopUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36';

class RouteProbe {
  HeadlessInAppWebView? _headless;

  /// Loads [url] invisibly, captures route responses + final HTML,
  /// writes everything to <app docs>/route_dump.txt (route_dump_desktop.txt
  /// when [desktop] is set, which loads the full desktop site instead of Lite).
  Future<File> run(
    WebUri url, {
    bool desktop = false,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
      '${dir.path}/${desktop ? 'route_dump_desktop' : 'route_dump'}.txt',
    );
    final sink = file.openWrite();
    final done = Completer<void>();
    var count = 0;
    var closed = false;

    void write(String label, String source, String body) {
      if (closed) return; // late responses after we've finished
      count++;
      sink.writeln(
        '===== #$count $label (${body.length} chars)\n$source\n$body\n',
      );
      debugPrint('[probe] #$count $label ${body.length} chars  $source');
    }

    _headless = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: url),
      initialSize: desktop ? const Size(1280, 800) : const Size(412, 900),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
        userAgent: desktop ? _desktopUserAgent : null,
        preferredContentMode: desktop ? UserPreferredContentMode.DESKTOP : null,
      ),
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: _interceptorJs,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      onWebViewCreated: (c) {
        c.addJavaScriptHandler(
          handlerName: 'captured',
          callback: (args) => write('XHR', '${args[0]}', '${args[1]}'),
        );
      },
      shouldOverrideUrlLoading: (_, action) async {
        final s = action.request.url?.scheme;
        return (s == 'http' || s == 'https')
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onLoadStop: (c, u) async {
        // Let the single-page app fire its route requests, then grab the HTML too
        // (the first route may be embedded in the page rather than fetched).
        await Future.delayed(const Duration(seconds: 6));
        final html = await c.evaluateJavascript(
          source: 'document.documentElement.outerHTML',
        );
        write('HTML', '$u', '$html');
        // The desktop site requests its route via <link rel=preload>, which the
        // XHR/fetch hooks never see — fetch those URLs ourselves.
        final preloaded = await c.callAsyncJavaScript(
          functionBody: r'''
            const links = [...document.querySelectorAll('link[href*="preview/directions"]')];
            const out = [];
            for (const l of links) {
              const r = await fetch(l.href, {credentials: 'include'});
              out.push([l.href, await r.text()]);
            }
            return out;
          ''',
        );
        for (final pair in (preloaded?.value as List?) ?? const []) {
          write('PRELOAD', '${pair[0]}', '${pair[1]}');
        }
        if (!done.isCompleted) done.complete();
      },
    );

    await _headless!.run();
    await done.future.timeout(timeout, onTimeout: () {});
    await _headless?.dispose();
    _headless = null;
    closed = true;
    await sink.flush();
    await sink.close();
    debugPrint('[probe] wrote $count entries to ${file.path}');
    return file;
  }
}
