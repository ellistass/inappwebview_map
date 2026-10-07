import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../../../../core/core.dart';
import '../models/directions_model.dart';
import 'directions_remote_datasource.dart';

/// The desktop site is the one that ships road geometry (`d[0][7]`); the
/// mobile/Lite site only gets maneuver points.
const _desktopUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36';

const _handlerName = 'directions';

/// Google's consent choice cookie. "CAI" is the "Reject all" answer: Google
/// stops redirecting to consent.google.com and serves Maps without
/// personalisation. Without it some devices (even outside the EU) get stuck
/// on the consent page and no route is ever requested.
Future<void> _setConsentCookie() {
  return CookieManager.instance().setCookie(
    url: WebUri('https://www.google.com'),
    name: 'SOCS',
    value: 'CAI',
    domain: '.google.com',
    path: '/',
    isSecure: true,
    expiresDate: DateTime.now()
        .add(const Duration(days: 365))
        .millisecondsSinceEpoch,
  );
}

/// Forwards the first `/maps/preview/directions` XHR/fetch body to Flutter
/// (queued until the bridge is ready).
const _captureJs = r'''
(function () {
  const MATCH = /\/maps\/preview\/directions/;
  let ready = false, pending = null;
  function emit(body) {
    const bridge = window.flutter_inappwebview;
    if (ready && bridge && typeof bridge.callHandler === 'function') {
      bridge.callHandler('directions', String(body));
    } else {
      pending = body;
    }
  }
  window.addEventListener('flutterInAppWebViewPlatformReady', function () {
    ready = true;
    if (pending !== null) emit(pending);
  });
  const oOpen = XMLHttpRequest.prototype.open;
  const oSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function (m, u) {
    this.__url = u;
    return oOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function () {
    this.addEventListener('load', () => {
      try { if (MATCH.test(this.__url)) emit(this.responseText); } catch (e) {}
    });
    return oSend.apply(this, arguments);
  };
  const oFetch = window.fetch;
  window.fetch = function (input) {
    return oFetch.apply(this, arguments).then((res) => {
      try {
        const u = typeof input === 'string' ? input : input.url;
        if (MATCH.test(u)) res.clone().text().then(emit);
      } catch (e) {}
      return res;
    });
  };
})();
''';

/// The desktop page may request directions through `<link rel=preload>`,
/// which the hooks above never see — fetch that URL ourselves.
const _fetchPreloadJs = r'''
const link = document.querySelector('link[href*="preview/directions"]');
if (!link) return null;
const r = await fetch(link.href, {credentials: 'include'});
return await r.text();
''';

/// Loads the Google Maps directions page in an invisible WebView and returns
/// the parsed route response.
class DirectionsRemoteDataSourceImpl implements DirectionsRemoteDataSource {
  final Duration timeout;

  const DirectionsRemoteDataSourceImpl({
    // Real phones are much slower than the emulator at loading desktop Maps.
    this.timeout = const Duration(seconds: 40),
  });

  @override
  Future<DirectionsModel> getDirections(RequestParam params) async {
    final query = params.toRequestMap().map((k, v) => MapEntry(k, '$v'));
    final url = Uri.https('www.google.com', '/maps/dir/', query);
    final body = Completer<String>();
    // Page loads and errors, reported if no route ever arrives.
    final trail = <String>[];
    void note(String line) {
      trail.add(line);
      debugPrint('[directions] $line');
    }

    void complete(Object? value) {
      if (value is String && value.isNotEmpty && !body.isCompleted) {
        body.complete(value);
      }
    }

    final webView = HeadlessInAppWebView(
      initialUrlRequest: URLRequest(url: WebUri(url.toString())),
      initialSize: const Size(1280, 800),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useShouldOverrideUrlLoading: true,
        userAgent: _desktopUserAgent,
        preferredContentMode: UserPreferredContentMode.DESKTOP,
      ),
      initialUserScripts: UnmodifiableListView([
        UserScript(
          source: _captureJs,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        ),
      ]),
      onWebViewCreated: (c) => c.addJavaScriptHandler(
        handlerName: _handlerName,
        callback: (args) => complete(args.firstOrNull),
      ),
      // Block intent://, comgooglemaps:// etc.
      shouldOverrideUrlLoading: (_, action) async {
        final s = action.request.url?.scheme;
        return (s == 'http' || s == 'https')
            ? NavigationActionPolicy.ALLOW
            : NavigationActionPolicy.CANCEL;
      },
      onLoadStart: (_, u) => note('load start $u'),
      onReceivedError: (_, req, err) => note(
        'error ${err.type} ${err.description} '
        '(${req.isForMainFrame == true ? 'page' : 'resource'} ${req.url})',
      ),
      onReceivedHttpError: (_, req, res) {
        if (req.isForMainFrame == true) {
          note('http ${res.statusCode} ${req.url}');
        }
      },
      onLoadStop: (c, u) async {
        note('load stop $u');
        if (body.isCompleted) return;
        final result = await c.callAsyncJavaScript(
          functionBody: _fetchPreloadJs,
        );
        complete(result?.value);
      },
    );

    await _setConsentCookie();
    try {
      await webView.run();
      final text = await body.future.timeout(
        timeout,
        onTimeout: () async => throw DirectionsTimeoutException(
          await _describePage(webView.webViewController),
          trail,
        ),
      );
      return DirectionsModel.fromResponse(text);
    } finally {
      await webView.dispose();
    }
  }

  /// Where the hidden page got stuck, e.g. a consent screen or an error page.
  Future<String> _describePage(InAppWebViewController? c) async {
    if (c == null) return 'page never opened';
    try {
      final url = await c.getUrl();
      final title = await c.getTitle();
      final text = await c.evaluateJavascript(
        source: "(document.body ? document.body.innerText : '').slice(0, 200)",
      );
      final snippet = '$text'.replaceAll(RegExp(r'\s+'), ' ').trim();
      return '${url?.host}${url?.path} — "$title" — $snippet';
    } catch (e) {
      return 'could not inspect page: $e';
    }
  }
}
