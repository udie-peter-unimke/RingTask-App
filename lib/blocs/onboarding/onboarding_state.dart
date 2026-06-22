part of 'onboarding_bloc.dart';

class OnboardingState extends Equatable {
  final int currentPage;
  final int totalPages;
  final bool isLastPage;
  final bool isComplete;

  const OnboardingState({
    this.currentPage = 0,
    this.totalPages = 8,
    this.isLastPage = false,
    this.isComplete = false,
  });

  OnboardingState copyWith({
    int? currentPage,
    int? totalPages,
    bool? isLastPage,
    bool? isComplete,
  }) {
    return OnboardingState(
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      isLastPage: isLastPage ?? this.isLastPage,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  @override
  List<Object?> get props => [currentPage, totalPages, isLastPage, isComplete];
}