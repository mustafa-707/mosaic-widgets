import 'package:mosaic_core/mosaic_core.dart';
import 'package:test/test.dart';

void main() {
  test('refresh sources parse', () {
    final c = MosaicConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b
widgets: []
refresh:
  refresh_news:
    url: https://api.example.com/news
    method: POST
    headers:
      Accept: application/json
    map:
      news_title: articles[0].title
      news_count: meta.total
''');
    expect(c.refresh, hasLength(1));
    final source = c.sourcesFor('refresh_news').single;
    expect(source.url, 'https://api.example.com/news');
    expect(source.method, 'POST');
    expect(source.headers, {'Accept': 'application/json'});
    expect(source.map, {
      'news_title': 'articles[0].title',
      'news_count': 'meta.total',
    });
  });

  test('method defaults to GET and headers to empty', () {
    final c = MosaicConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b
widgets: []
refresh:
  refresh_all:
    url: https://api.example.com/all
    map:
      temp: current.temp_f
''');
    final source = c.sourcesFor('refresh_all').single;
    expect(source.method, 'GET');
    expect(source.headers, isEmpty);
  });

  test('a callback may declare a list of sources', () {
    final c = MosaicConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b.widgets
widgets: []
refresh:
  refresh_weather:
    - url: https://api.example.com/weather?unit=c
      map:
        temp_c: current.temperature_2m
    - url: https://api.example.com/weather?unit=f
      map:
        temp_f: current.temperature_2m
''');
    final sources = c.sourcesFor('refresh_weather');
    expect(sources, hasLength(2));
    expect(sources[0].map, {'temp_c': 'current.temperature_2m'});
    expect(sources[1].map, {'temp_f': 'current.temperature_2m'});
  });

  test('sourcesFor an undeclared callback is empty', () {
    final c = MosaicConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b.widgets
widgets: []
''');
    expect(c.sourcesFor('nope'), isEmpty);
  });

  test('config without refresh yields empty map (back-compat)', () {
    final c = MosaicConfig.fromYaml('''
app:
  bundle_id: com.a.b
  android_package: com.a.b
  ios_app_group: group.com.a.b
widgets: []
''');
    expect(c.refresh, isEmpty);
  });
}
