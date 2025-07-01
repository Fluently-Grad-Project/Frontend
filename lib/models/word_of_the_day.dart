class WordOfTheDay {
  final String word;
  final String partsOfSpeech;
  final String description;
  final String example;

  WordOfTheDay({
    required this.word,
    required this.partsOfSpeech,
    required this.description,
    required this.example,
  });

  factory WordOfTheDay.fromJson(Map<String, dynamic> json) {
    return WordOfTheDay(
      word: json['word'],
      partsOfSpeech: json['parts_of_speech'],
      description: json['description'],
      example: json['example'],
    );
  }
}
