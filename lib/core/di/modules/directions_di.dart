import 'package:get_it/get_it.dart';

import '../../../features/directions/data/data.dart';
import '../../../features/directions/domain/domain.dart';
import '../../../features/directions/presentation/bloc/directions_bloc.dart';
import '../../../features/directions/presentation/bloc/directions_form_cubit.dart';
import '../../../features/directions/presentation/bloc/navigation_bloc.dart';

void registerDirections(GetIt getIt) {
  getIt
    // Data sources
    ..registerLazySingleton<DirectionsRemoteDataSource>(
      () => const DirectionsRemoteDataSourceImpl(),
    )
    ..registerLazySingleton<LocationDataSource>(
      () => const LocationDataSourceImpl(),
    )
    // Repositories
    ..registerLazySingleton<DirectionsRepository>(
      () => DirectionsRepositoryImpl(getIt()),
    )
    ..registerLazySingleton<LocationRepository>(
      () => LocationRepositoryImpl(getIt()),
    )
    // Use cases
    ..registerFactory(() => GetDirectionsUseCase(getIt()))
    ..registerFactory(() => EnsureLocationPermissionUseCase(getIt()))
    ..registerFactory(() => WatchLocationUseCase(getIt()))
    ..registerFactory(() => GetCurrentLocationUseCase(getIt()))
    // Blocs / cubits
    ..registerFactory(() => DirectionsBloc(getIt()))
    ..registerFactory(() => NavigationBloc(getIt(), getIt(), getIt()))
    ..registerFactory(() => DirectionsFormCubit(getIt()));
}
