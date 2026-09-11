import 'package:equatable/equatable.dart';

class InternetState extends Equatable {
  final bool isConnected;

  const InternetState({required this.isConnected});

  @override
  List<Object> get props => [isConnected];
}