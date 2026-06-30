class Account {
  final int? id;
  final String name;
  final String icon;
  final bool isDefault;

  const Account({
    this.id,
    required this.name,
    required this.icon,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'icon': icon,
    'is_default': isDefault ? 1 : 0,
  };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
    id: map['id'] as int?,
    name: map['name'] as String,
    icon: map['icon'] as String,
    isDefault: (map['is_default'] as int? ?? 0) == 1,
  );

  Account copyWith({int? id, String? name, String? icon, bool? isDefault}) =>
      Account(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        isDefault: isDefault ?? this.isDefault,
      );
}

const defaultAccounts = [
  Account(id: 1, name: 'Perso', icon: '👤', isDefault: true),
  Account(id: 2, name: 'Pro', icon: '💼'),
];
