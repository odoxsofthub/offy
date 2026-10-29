import 'package:image_picker/image_picker.dart';
import '../repositories/expense_repository.dart';

class SubmitExpenseUseCase {
  final ExpenseRepository repository;

  SubmitExpenseUseCase(this.repository);

  Future<bool> call(Map<String, String> data, List<XFile> files) async {
    return await repository.submitExpense(data, files);
  }
}
