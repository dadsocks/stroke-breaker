enum DistanceBucket { short, medium, long }

extension DistanceBucketRange on DistanceBucket {
  int get minFeet {
    switch (this) {
      case DistanceBucket.short:
        return 4;
      case DistanceBucket.medium:
        return 11;
      case DistanceBucket.long:
        return 26;
    }
  }

  int get maxFeet {
    switch (this) {
      case DistanceBucket.short:
        return 10;
      case DistanceBucket.medium:
        return 25;
      case DistanceBucket.long:
        return 40;
    }
  }
}

DistanceBucket bucketForDistance(int distanceFeet) {
  if (distanceFeet <= DistanceBucket.short.maxFeet) {
    return DistanceBucket.short;
  }
  if (distanceFeet <= DistanceBucket.medium.maxFeet) {
    return DistanceBucket.medium;
  }
  return DistanceBucket.long;
}
