class OpportunityModel {
  const OpportunityModel({
    required this.id,
    required this.title,
    required this.provider,
    required this.deadline,
    required this.eligibility,
    required this.link,
  });

  final int id;
  final String title;
  final String provider;
  final String deadline;
  final String eligibility;
  final String link;

  factory OpportunityModel.fromJson(Map<String, dynamic> json) {
    return OpportunityModel(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Untitled',
      provider: json['provider'] as String? ?? 'Unknown provider',
      deadline: json['deadline'] as String? ?? 'N/A',
      eligibility: json['eligibility'] as String? ?? 'N/A',
      link: json['link'] as String? ?? '',
    );
  }
}
