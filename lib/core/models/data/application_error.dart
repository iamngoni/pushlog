//
//  pushlog
//  application_error.dart
//
//  Created by Ngonidzashe Mangudya on 2026/04/16.
//  Copyright (c) 2026 Codecraft Solutions. All rights reserved.
//

import 'package:equatable/equatable.dart';

class ApplicationError extends Equatable {
  const ApplicationError({
    required this.message,
    this.code,
  });

  factory ApplicationError.unknownError() => const ApplicationError(
    message: 'An unexpected error occurred.',
    code: 'unknown',
  );

  factory ApplicationError.storageError(String detail) => ApplicationError(
    message: 'Storage error: $detail',
    code: 'storage_error',
  );

  factory ApplicationError.serializationError() => const ApplicationError(
    message: 'Failed to read stored data.',
    code: 'serialization_error',
  );

  final String message;
  final String? code;

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => 'ApplicationError(code: $code, message: $message)';
}
