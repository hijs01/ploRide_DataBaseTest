class Prediction {
  final String placeId;
  final String mainText;
  final String secondaryText;

  Prediction({
    required this.placeId,
    required this.mainText,
    required this.secondaryText,
  });
  //  원래코드는 required가 없었음, 일단 커서가 붙이라고해서 붙여봤는데 에러 안남

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      placeId: json['place_id'] as String,
      mainText: json['structured_formatting']['main_text'] as String,
      secondaryText: json['structured_formatting']['secondary_text'] as String,
    );
  }
}
