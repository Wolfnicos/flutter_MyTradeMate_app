import 'dart:convert';
import 'dart:io';

String _p(String name) => 'test/fixtures/$name';

String loadFixtureString(String name) => File(_p(name)).readAsStringSync();
dynamic loadFixtureJson(String name) => jsonDecode(loadFixtureString(name));



