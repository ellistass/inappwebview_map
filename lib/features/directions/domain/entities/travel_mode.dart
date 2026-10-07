/// Values match Google's `travelmode` URL parameter.
enum TravelMode {
  driving,
  walking,
  transit,
  bicycling;

  bool get isDriving => this == TravelMode.driving;
  bool get isWalking => this == TravelMode.walking;
  bool get isTransit => this == TravelMode.transit;
  bool get isBicycling => this == TravelMode.bicycling;
}
