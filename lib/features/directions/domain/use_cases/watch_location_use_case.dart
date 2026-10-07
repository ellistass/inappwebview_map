import '../entities/user_location_entity.dart';
import '../repositories/location_repository.dart';

class WatchLocationUseCase {
  final LocationRepository _repository;

  const WatchLocationUseCase(this._repository);

  Stream<UserLocationEntity> call() => _repository.watchLocation();
}
