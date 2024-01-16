import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

import 'datamodel.dart';

part 'data_event.dart';
part 'data_state.dart';

class DataBloc extends Bloc<DataEvent, DataState> {
  final Box<DataModel> dataBox;

  DataBloc({required this.dataBox}) : super(DataInitial()) {
    on<FetchData>(_mapFetchDataToState);
    on<AddData>(_mapAddDataToState);
  }

  Stream<DataState> _mapFetchDataToState(
    FetchData event,
    Emitter<DataState> emit,
  ) async* {
    emit(DataLoading());
    try {
      final List<DataModel> dataList = dataBox.values.toList();
      emit(DataLoaded(dataList));
    } catch (e) {
      emit(const DataError('Failed to fetch data'));
    }
  }

  Stream<DataState> _mapAddDataToState(
    AddData event,
    Emitter<DataState> emit,
  ) async* {
    try {
      final newData = DataModel(event.dateTime);
      await dataBox.add(newData);
      final List<DataModel> dataList = dataBox.values.toList();
      yield DataLoaded(dataList);
    } catch (e) {
      yield const DataError('Failed to add data');
    }
  }
}
