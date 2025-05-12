class Habit {
  String id;
  String title;
  String unit;
  double goal;
  double currentValue;
  List<double> quickAdds;
  bool usePedometer;

  Habit({
    required this.id,
    required this.title,
    required this.unit,
    required this.goal,
    required this.currentValue,
    required this.quickAdds,
    this.usePedometer = false,
  });

  Habit copyWith({double? currentValue}) => Habit(
    id: id,
    title: title,
    unit: unit,
    goal: goal,
    currentValue: currentValue ?? this.currentValue,
    quickAdds: quickAdds,
    usePedometer: usePedometer,
  );
}
