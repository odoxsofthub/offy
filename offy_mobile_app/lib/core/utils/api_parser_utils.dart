/// Safely parses an API field into [T]. Returns null for null, and for a `bool` where a non-bool is
/// expected (Odoo sends `false` for empty fields).
T? parseField<T extends Object>(dynamic value) {
  if (value == null) return null;

  if (T == bool) {
    return (value is bool ? value : null) as T?;
  }

  // If a boolean value comes for a non-boolean target variable type, return null
  if (value is bool) {
    return null;
  }

  if (value is T) {
    return value as T?;
  }

  if (T == String) {
    final str = value.toString().trim();
    return (str.isEmpty ? null : str) as T?;
  }

  if (T == int) {
    if (value is num) return value.toInt() as T?;
    return int.tryParse(value.toString()) as T?;
  }

  if (T == double) {
    if (value is num) return value.toDouble() as T?;
    return double.tryParse(value.toString()) as T?;
  }

  if (T == num) {
    return num.tryParse(value.toString()) as T?;
  }

  return null;
}
