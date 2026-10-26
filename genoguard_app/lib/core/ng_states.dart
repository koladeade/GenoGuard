/// Nigerian states (plus the FCT) and the city used to look up their weather.
/// The profile stores the state name; weather uses the city.
const Map<String, String> kNgStateCities = {
  'Abia': 'Umuahia',
  'Abuja (FCT)': 'Abuja',
  'Adamawa': 'Yola',
  'Akwa Ibom': 'Uyo',
  'Anambra': 'Awka',
  'Bauchi': 'Bauchi',
  'Bayelsa': 'Yenagoa',
  'Benue': 'Makurdi',
  'Borno': 'Maiduguri',
  'Cross River': 'Calabar',
  'Delta': 'Asaba',
  'Ebonyi': 'Abakaliki',
  'Edo': 'Benin City',
  'Ekiti': 'Ado Ekiti',
  'Enugu': 'Enugu',
  'Gombe': 'Gombe',
  'Imo': 'Owerri',
  'Jigawa': 'Dutse',
  'Kaduna': 'Kaduna',
  'Kano': 'Kano',
  'Katsina': 'Katsina',
  'Kebbi': 'Birnin Kebbi',
  'Kogi': 'Lokoja',
  'Kwara': 'Ilorin',
  'Lagos': 'Lagos',
  'Nasarawa': 'Lafia',
  'Niger': 'Minna',
  'Ogun': 'Abeokuta',
  'Ondo': 'Akure',
  'Osun': 'Osogbo',
  'Oyo': 'Ibadan',
  'Plateau': 'Jos',
  'Rivers': 'Port Harcourt',
  'Sokoto': 'Sokoto',
  'Taraba': 'Jalingo',
  'Yobe': 'Damaturu',
  'Zamfara': 'Gusau',
};

final List<String> kNgStateNames = kNgStateCities.keys.toList();

/// Turns a saved location into a place name the weather lookup understands.
/// "Kano" -> "Kano", "Plateau" -> "Jos", "FCT" -> "Abuja". Anything else is
/// returned unchanged (free text such as "Ikeja" still works).
String weatherPlaceFor(String text) {
  final t = text.trim().toLowerCase();
  if (t == 'fct' || t == 'abuja (fct)') return 'Abuja';
  for (final e in kNgStateCities.entries) {
    if (e.key.toLowerCase() == t) return e.value;
  }
  return text.trim();
}
