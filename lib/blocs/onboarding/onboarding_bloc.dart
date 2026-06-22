import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ringtask/data/datasources/local/cache_manager.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final CacheManager _cacheManager;

  // Pass CacheManager into the constructor
  OnboardingBloc({required CacheManager cacheManager})
      : _cacheManager = cacheManager,
        super(const OnboardingState()) {
    on<OnboardingPageChanged>(_onPageChanged);
    on<OnboardingNextTapped>(_onNextTapped);
    on<OnboardingSkipTapped>(_onSkipTapped);
    on<OnboardingCompleted>(_onCompleted);
  }

  void _onPageChanged(
      OnboardingPageChanged event,
      Emitter<OnboardingState> emit,
      ) {
    emit(state.copyWith(
      currentPage: event.page,
      isLastPage: event.page == state.totalPages - 1,
      isComplete: false,
    ));
  }

  void _onNextTapped(
      OnboardingNextTapped event,
      Emitter<OnboardingState> emit,
      ) {
    if (state.currentPage < state.totalPages - 1) {
      final nextPage = state.currentPage + 1;
      emit(state.copyWith(
        currentPage: nextPage,
        isLastPage: nextPage == state.totalPages - 1,
      ));
    }
  }

  void _onSkipTapped(
      OnboardingSkipTapped event,
      Emitter<OnboardingState> emit,
      ) {
    emit(state.copyWith(
      currentPage: state.totalPages - 1,
      isLastPage: true,
    ));
  }

  // Changed to async to support writing to storage
  Future<void> _onCompleted(
      OnboardingCompleted event,
      Emitter<OnboardingState> emit,
      ) async {
    try {
      // 1. Permanently save onboarding completion flag to local cache
      await _cacheManager.setOnboardingSeen();
    } catch (_) {
      // Optional: Handle caching failure logs here if necessary
    }

    // 2. Alert UI to navigate forward
    emit(state.copyWith(isComplete: true));
  }
}