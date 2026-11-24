import '../repositories/repository.dart';
import 'row_codecs.dart';
import 'row_gateway.dart';

/// A [Repository] backed by a database table.
///
/// Screens work from an in-memory list, so [getAll] must answer instantly: [load] fills it from the database
/// once after sign-in. Saves go to the database first and only update the local copy once they succeed, so the
/// copy never claims more than the database has.
class SupabaseRepository<T> implements Repository<T> {
  SupabaseRepository(this._gateway, this.codec);

  final RowGateway _gateway;
  final RowCodec<T> codec;

  List<T> _cache = const [];

  /// Read every row this person is allowed to see. Row Level Security filters on the server, so asking for
  /// everything returns only what they may see.
  Future<void> load() async {
    final rows = await _gateway.select(codec.table, orderBy: codec.orderBy, limit: codec.limit);
    _cache = [for (final row in rows) codec.fromRow(row)];
  }

  @override
  List<T> getAll() => List.unmodifiable(_cache);

  @override
  Future<void> upsert(T item) async {
    await _gateway.upsert(codec.table, codec.toRow(item));
    final id = codec.idOf(item);
    final index = _cache.indexWhere((e) => codec.idOf(e) == id);
    _cache = index < 0 ? [item, ..._cache] : ([..._cache]..[index] = item);
  }

  @override
  Future<void> delete(String id) async {
    await _gateway.delete(codec.table, id);
    _cache = _cache.where((e) => codec.idOf(e) != id).toList();
  }
}
