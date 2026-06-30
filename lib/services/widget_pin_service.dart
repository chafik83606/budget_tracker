import 'dart:io';
import 'package:flutter/services.dart';

class WidgetPinService {
  WidgetPinService._();
  static final WidgetPinService instance = WidgetPinService._();

  static const _channel = MethodChannel('com.dynaweb.budgettracker/widget');

  Future<bool> requestPinWidget() async {
    if (!Platform.isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('requestPinWidget');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }
}
