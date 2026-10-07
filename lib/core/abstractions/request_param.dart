import 'package:equatable/equatable.dart';

abstract class RequestParam extends Equatable {
  const RequestParam();

  /// Override to produce the query params sent to the data source.
  Map<String, dynamic> toRequestMap();
}
