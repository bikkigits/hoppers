const String pandalsJson = '''
[
  {
    "id": "sample-001",
    "name": "Sample Sarbojanin Durgotsav (Shyambazar)",
    "theme": "Terracotta Temples of Bengal",
    "zone": "north",
    "lat": 22.5985,
    "lng": 88.3723,
    "nearestMetroId": "shyambazar",
    "nearestMetroName": "Shyambazar",
    "verified": true,
    "crowdLevel": "medium"
  },
  {
    "id": "sample-002",
    "name": "Sample Yuba Sangha (Kalighat)",
    "theme": "Handwoven Jamdani Dreams",
    "zone": "south",
    "lat": 22.5193,
    "lng": 88.3426,
    "nearestMetroId": "kalighat",
    "nearestMetroName": "Kalighat",
    "verified": true,
    "crowdLevel": "insane"
  }
]
''';

const String metroGraphJson = '''
{
  "stations": [
    {"id": "shyambazar", "name": "Shyambazar", "lat": 22.6009, "lng": 88.3732},
    {"id": "kalighat", "name": "Kalighat", "lat": 22.5186, "lng": 88.3444}
  ],
  "edges": [
    {"from": "shyambazar", "to": "kalighat", "minutes": 25.0, "line": "Blue"}
  ]
}
''';