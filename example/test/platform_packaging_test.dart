import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reads a UTF-8 file from the example package root.
String read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'missing $path');
  return file.readAsStringSync();
}

/// Asserts that [path] exists, relative to the example package root.
void expectFile(String path) {
  expect(File(path).existsSync(), isTrue, reason: 'missing $path');
}

/// The Android and Windows platform projects are what "platform support" means
/// for this example, and every one of these files is easy to lose in a
/// refactor: a dropped camera permission, a renamed window title or a stale
/// plugin registrant only shows up on the device. The test guards the contract
/// on any host, including the Linux CI runner that builds neither platform.
void main() {
  group('Android', () {
    test(
      'the manifest asks for the camera and keeps the hardware optional',
      () {
        final manifest = read('android/app/src/main/AndroidManifest.xml');

        // mobile_scanner decodes frames with the camera...
        expect(manifest, contains('android.permission.CAMERA'));
        // ...but the app also works without one (image scan), so Play must not
        // filter camera-less devices out.
        expect(manifest, contains('android.hardware.camera'));
        expect(manifest, contains('android.hardware.camera.autofocus'));
        expect(manifest, contains('android:required="false"'));
      },
    );

    test('the launcher entry points at both icon shapes', () {
      final manifest = read('android/app/src/main/AndroidManifest.xml');

      expect(manifest, contains('android:label="QRS Dart"'));
      expect(manifest, contains('android:icon="@mipmap/ic_launcher"'));
      expect(
        manifest,
        contains('android:roundIcon="@mipmap/ic_launcher_round"'),
      );
      expect(manifest, contains('.MainActivity'));
    });

    test('the activity lives under the application id', () {
      final activity = read(
        'android/app/src/main/kotlin/dev/simon/qrs_dart_example/'
        'MainActivity.kt',
      );

      expect(activity, contains('package dev.simon.qrs_dart_example'));
      expect(activity, contains('class MainActivity : FlutterActivity()'));
    });

    test('the gradle project builds a release with or without a keystore', () {
      final gradle = read('android/app/build.gradle.kts');

      expect(gradle, contains('applicationId = "dev.simon.qrs_dart_example"'));
      expect(gradle, contains('namespace = "dev.simon.qrs_dart_example"'));
      // A local keystore signs the release build; without one the debug keys
      // are used, which is what CI relies on.
      expect(gradle, contains('key.properties'));
      expect(gradle, contains('signingConfigs.getByName("debug")'));
      // mobile_scanner needs API 23 and file_picker API 21: both are below
      // Flutter's own floor, so the Flutter default is the correct value.
      expect(gradle, contains('minSdk = flutter.minSdkVersion'));
    });

    test('Flutter knows the platform exists', () {
      expect(read('.metadata'), contains('platform: android'));
    });
  });

  group('Windows', () {
    test('the CMake project builds the runner binary', () {
      final cmake = read('windows/CMakeLists.txt');

      expect(cmake, contains('project(qrs_dart_example LANGUAGES CXX)'));
      expect(cmake, contains('set(BINARY_NAME "qrs_dart_example")'));
      expect(cmake, contains('cmake_minimum_required(VERSION 3.14)'));
    });

    test('the complete runner source set is present', () {
      for (final path in <String>[
        'windows/runner/main.cpp',
        'windows/runner/flutter_window.cpp',
        'windows/runner/flutter_window.h',
        'windows/runner/win32_window.cpp',
        'windows/runner/win32_window.h',
        'windows/runner/utils.cpp',
        'windows/runner/utils.h',
        'windows/runner/Runner.rc',
        'windows/runner/runner.exe.manifest',
        'windows/runner/resources/app_icon.ico',
        'windows/runner/CMakeLists.txt',
        'windows/flutter/CMakeLists.txt',
        'windows/flutter/generated_plugin_registrant.cc',
        'windows/flutter/generated_plugins.cmake',
      ]) {
        expectFile(path);
      }
    });

    test('the window and the executable are named QRS Dart', () {
      expect(read('windows/runner/main.cpp'), contains('L"QRS Dart"'));

      final resources = read('windows/runner/Runner.rc');
      expect(resources, contains('VALUE "ProductName", "QRS Dart"'));
      expect(resources, contains('VALUE "FileDescription", "QRS Dart"'));
      // The file name stays the binary name, so scripts keep working.
      expect(
        resources,
        contains('VALUE "OriginalFilename", "qrs_dart_example.exe"'),
      );
    });

    test('the plugin registrant is generated for the app', () {
      // file_picker's Windows implementation uses win32 FFI, so it registers
      // no native plugin; the generated files must exist and stay compilable.
      final registrant = read('windows/flutter/generated_plugin_registrant.cc');
      expect(registrant, contains('RegisterPlugins'));
      expect(
        read('windows/flutter/generated_plugins.cmake'),
        contains('FLUTTER_PLUGIN_LIST'),
      );
    });

    test('Flutter knows the platform exists', () {
      expect(read('.metadata'), contains('platform: windows'));
    });
  });
}
