import 'dart:async';
import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:registration_delivery/models/entities/household_member.dart';
import 'package:registration_delivery/models/entities/task.dart';
import 'package:registration_delivery/models/entities/task_resource.dart';
import 'package:registration_delivery/utils/typedefs.dart';
import 'package:inventory_management/models/entities/stock.dart';
import 'package:inventory_management/models/entities/transaction_type.dart';
import 'package:inventory_management/utils/typedefs.dart' as inventory_types;


import '../../models/entities/assessment_checklist/status.dart';
import '../../utils/constants.dart';
import '../../utils/date_utils.dart';

part 'custom_summary_report_bloc.freezed.dart';

typedef SummaryReportEmitter = Emitter<SummaryReportState>;

class SummaryReportBloc extends Bloc<SummaryReportEvent, SummaryReportState> {
  final HouseholdMemberDataRepository householdMemberRepository;
  final TaskDataRepository taskDataRepository;
  final ProductVariantDataRepository productVariantDataRepository;
  final inventory_types.StockDataRepository stockDataRepository;

  SummaryReportBloc({
    required this.householdMemberRepository,
    required this.productVariantDataRepository,
    required this.taskDataRepository,
    required this.stockDataRepository,
  }) : super(const SummaryReportEmptyState()) {
    on<SummaryReportLoadDataEvent>(_handleLoadDataEvent);
    on<SummaryReportLoadingEvent>(_handleLoadingEvent);
  }

  Future<void> _handleLoadDataEvent(
    SummaryReportLoadDataEvent event,
    SummaryReportEmitter emit,
  ) async {
    emit(const SummaryReportLoadingState());

    List<HouseholdMemberModel> householdMemberList = [];
    List<HouseholdMemberModel> householdHeadsList = [];
    List<TaskModel> taskList = [];
    List<TaskModel> refusalCasesList = [];
    List<TaskModel> administeredChildrenList = [];
    List<ProductVariantModel> productVariantList = [];
    List<TaskResourceModel> spaq1List = [];
    List<TaskResourceModel> spaq2List = [];
    List<StockModel> stockReceivedList = [];
    List<StockModel> spaq1StockReceivedList = [];
    List<StockModel> spaq2StockReceivedList = [];
    List<StockModel> spaq1StockDamagedList = [];
    List<StockModel> spaq2StockDamagedList = [];
    List<StockModel> spaq1StockLostList = [];
    List<StockModel> spaq2StockLostList = [];
    householdMemberList = await (householdMemberRepository)
        .search(HouseholdMemberSearchModel(isHeadOfHousehold: false));
    householdHeadsList = await (householdMemberRepository)
        .search(HouseholdMemberSearchModel(isHeadOfHousehold: true));
    taskList = await (taskDataRepository).search(TaskSearchModel());
    productVariantList = await (productVariantDataRepository)
        .search(ProductVariantSearchModel());
    
    // Filter received stock by current user only
    stockReceivedList = await (stockDataRepository).search(StockSearchModel(
        transactionType: [TransactionType.received.toValue()],
        receiverId: [event.userId]));
    
    // Get all dispatched stock to filter by reason later, filter by current user only
    List<StockModel> allDispatchedStock = await (stockDataRepository).search(StockSearchModel(
        transactionType: [TransactionType.dispatched.toValue()],
        senderId: event.userId));
    for (var element in taskList) {
      final status = StatusMapper.fromValue(element.status);

      if (status == Status.administeredSuccess) {
        administeredChildrenList.add(element);
      } else if (status == Status.beneficiaryRefused) {
        refusalCasesList.add(element);
      }
    }

    for (var task in administeredChildrenList) {
      for (var resource in task.resources!) {
        for (var productVariant in productVariantList) {
          if (productVariant.id == resource.productVariantId &&
              productVariant.sku == Constants.spaq1) {
            spaq1List.add(resource);
          } else if (productVariant.id == resource.productVariantId &&
              productVariant.sku == Constants.spaq2) {
            spaq2List.add(resource);
          }
        }
      }
    }

    // Separate received stock by product type
    for (var stock in stockReceivedList) {
      final productName = stock.additionalFields?.fields
          .firstWhereOrNull((f) => f.key == "productName")
          ?.value;
     
      // Try using productVariantId if productName is null
      if (productName == null && stock.productVariantId != null) {
        final productVariant = productVariantList.firstWhereOrNull(
          (pv) => pv.id == stock.productVariantId
        );
        if (productVariant != null) {
          if (productVariant.sku == Constants.spaq1) {
            spaq1StockReceivedList.add(stock);
          } else if (productVariant.sku == Constants.spaq2) {
            spaq2StockReceivedList.add(stock);
          }
        }
      } else if (productName == Constants.spaq1) {
        spaq1StockReceivedList.add(stock);
      } else if (productName == Constants.spaq2) {
        spaq2StockReceivedList.add(stock);
      }
    }

    // Separate dispatched stock by product type and reason (damaged/lost)
    for (var stock in allDispatchedStock) {
      final productName = stock.additionalFields?.fields
          .firstWhereOrNull((f) => f.key == "productName")
          ?.value;
      
      final transactionReason = stock.transactionReason;
      bool isDamaged = transactionReason != null && (
        transactionReason.toUpperCase().contains("DAMAGED") ||
        transactionReason == "DAMAGED_IN_STORAGE" || 
        transactionReason == "DAMAGED_IN_TRANSIT"
      );
      bool isLost = transactionReason != null && (
        transactionReason.toUpperCase().contains("LOST") ||
        transactionReason == "LOST_IN_STORAGE" || 
        transactionReason == "LOST_IN_TRANSIT"
      );
      

      
      // Try using productVariantId if productName is null
      if (productName == null && stock.productVariantId != null) {
        final productVariant = productVariantList.firstWhereOrNull(
          (pv) => pv.id == stock.productVariantId
        );
        if (productVariant != null) {
          if (productVariant.sku == Constants.spaq1) {
            if (isDamaged) {
              spaq1StockDamagedList.add(stock);
            } else if (isLost) {
              spaq1StockLostList.add(stock);
            }
          } else if (productVariant.sku == Constants.spaq2) {
            if (isDamaged) {
              spaq2StockDamagedList.add(stock);
            } else if (isLost) {
              spaq2StockLostList.add(stock);
            }
          }
        }
      } else if (productName == Constants.spaq1) {
        if (isDamaged) {
          spaq1StockDamagedList.add(stock);
        } else if (isLost) {
          spaq1StockLostList.add(stock);
        }
      } else if (productName == Constants.spaq2) {
        if (isDamaged) {
          spaq2StockDamagedList.add(stock);
        } else if (isLost) {
          spaq2StockLostList.add(stock);
        }
      }
    }



    Map<String, List<HouseholdMemberModel>> dateVsHouseholdMembersList = {};
    Map<String, List<HouseholdMemberModel>> dateVsHouseholdHeadsList = {};
    Map<String, List<TaskModel>> dateVsAdministeredChilderenList = {};
    Map<String, List<TaskModel>> dateVsRefusalCasesList = {};
    Map<String, List<TaskResourceModel>> dateVsSpaq1List = {};
    Map<String, List<TaskResourceModel>> dateVsSpaq2List = {};
    Map<String, List<StockModel>> dateVsSpaq1StockReceivedList = {};
    Map<String, List<StockModel>> dateVsSpaq2StockReceivedList = {};
    Map<String, List<StockModel>> dateVsSpaq1StockDamagedList = {};
    Map<String, List<StockModel>> dateVsSpaq2StockDamagedList = {};
    Map<String, List<StockModel>> dateVsSpaq1StockLostList = {};
    Map<String, List<StockModel>> dateVsSpaq2StockLostList = {};
    Set<String> uniqueDates = {};
    Map<String, int> dateVsHouseholdMembersCount = {};
    Map<String, int> dateVsHouseholdHeadsCount = {};
    Map<String, int> dateVsAdministeredChilderenCount = {};
    Map<String, int> dateVsRefusalCasesCount = {};
    Map<String, int> dateVsSpaq1Count = {};
    Map<String, int> dateVsSpaq2Count = {};
    Map<String, int> dateVsSpaq1StockReceivedCount = {};
    Map<String, int> dateVsSpaq2StockReceivedCount = {};
    Map<String, int> dateVsSpaq1StockDamagedCount = {};
    Map<String, int> dateVsSpaq2StockDamagedCount = {};
    Map<String, int> dateVsSpaq1StockLostCount = {};
    Map<String, int> dateVsSpaq2StockLostCount = {};
    Map<String, Map<String, int>> dateVsEntityVsCountMap = {};
    for (var element in householdMemberList) {
      var dateKey = DigitDateUtils.getDateFromTimestamp(
          element.clientAuditDetails!.createdTime);
      dateVsHouseholdMembersList.putIfAbsent(dateKey, () => []).add(element);
    }
    for (var element in householdHeadsList) {
      var dateKey = DigitDateUtils.getDateFromTimestamp(
          element.clientAuditDetails!.createdTime);
      dateVsHouseholdHeadsList.putIfAbsent(dateKey, () => []).add(element);
    }
    for (var element in administeredChildrenList) {
      var dateKey = DigitDateUtils.getDateFromTimestamp(
          element.clientAuditDetails!.createdTime);
      dateVsAdministeredChilderenList
          .putIfAbsent(dateKey, () => [])
          .add(element);
    }
    for (var element in refusalCasesList) {
      var dateKey = DigitDateUtils.getDateFromTimestamp(
          element.clientAuditDetails!.createdTime);
      dateVsRefusalCasesList.putIfAbsent(dateKey, () => []).add(element);
    }

    for (var element in spaq1List) {
      var dateKey = DigitDateUtils.getDateFromTimestamp(
          element.auditDetails!.createdTime);
      dateVsSpaq1List.putIfAbsent(dateKey, () => []).add(element);
    }
    for (var element in spaq2List) {
      var dateKey = DigitDateUtils.getDateFromTimestamp(
          element.auditDetails!.createdTime);
      dateVsSpaq2List.putIfAbsent(dateKey, () => []).add(element);
    }

    // Group stock by date
    for (var element in spaq1StockReceivedList) {
      var dateKey = DigitDateUtils.getDateFromTimestamp(
          element.auditDetails!.createdTime);
      dateVsSpaq1StockReceivedList.putIfAbsent(dateKey, () => []).add(element);
    }
    for (var element in spaq2StockReceivedList) {
      var dateKey = DigitDateUtils.getDateFromTimestamp(
          element.auditDetails!.createdTime);
      dateVsSpaq2StockReceivedList.putIfAbsent(dateKey, () => []).add(element);
    }
    for (var element in spaq1StockDamagedList) {
      var dateKey = DigitDateUtils.getDateFromTimestamp(
          element.auditDetails!.createdTime);
      dateVsSpaq1StockDamagedList.putIfAbsent(dateKey, () => []).add(element);
    }
    for (var element in spaq2StockDamagedList) {
      var dateKey = DigitDateUtils.getDateFromTimestamp(
          element.auditDetails!.createdTime);
      dateVsSpaq2StockDamagedList.putIfAbsent(dateKey, () => []).add(element);
    }
    for (var element in spaq1StockLostList) {
      var dateKey = DigitDateUtils.getDateFromTimestamp(
          element.auditDetails!.createdTime);
      dateVsSpaq1StockLostList.putIfAbsent(dateKey, () => []).add(element);
    }
    for (var element in spaq2StockLostList) {
      var dateKey = DigitDateUtils.getDateFromTimestamp(
          element.auditDetails!.createdTime);
      dateVsSpaq2StockLostList.putIfAbsent(dateKey, () => []).add(element);
    }

    // get a set of unique dates
    getUniqueSetOfDates(
      dateVsHouseholdMembersList,
      dateVsHouseholdHeadsList,
      dateVsAdministeredChilderenList,
      dateVsRefusalCasesList,
      dateVsSpaq1List,
      dateVsSpaq2List,
      dateVsSpaq1StockReceivedList,
      dateVsSpaq2StockReceivedList,
      dateVsSpaq1StockDamagedList,
      dateVsSpaq2StockDamagedList,
      dateVsSpaq1StockLostList,
      dateVsSpaq2StockLostList,
      uniqueDates,
    );

    // populate the day vs count for that day map
    populateDateVsCountMap(
        dateVsHouseholdMembersList, dateVsHouseholdMembersCount);
    populateDateVsCountMap(
        dateVsHouseholdHeadsList, dateVsHouseholdHeadsCount);
    populateDateVsCountMap(
        dateVsAdministeredChilderenList, dateVsAdministeredChilderenCount);
    populateDateVsCountMap(dateVsRefusalCasesList, dateVsRefusalCasesCount);

    populateDateVsCountMap(dateVsSpaq1List, dateVsSpaq1Count);
    populateDateVsCountMap(dateVsSpaq2List, dateVsSpaq2Count);

    // populate stock counts using quantity field
    populateDateVsCountMapForStock(dateVsSpaq1StockReceivedList, dateVsSpaq1StockReceivedCount);
    populateDateVsCountMapForStock(dateVsSpaq2StockReceivedList, dateVsSpaq2StockReceivedCount);
    populateDateVsCountMapForStock(dateVsSpaq1StockDamagedList, dateVsSpaq1StockDamagedCount);
    populateDateVsCountMapForStock(dateVsSpaq2StockDamagedList, dateVsSpaq2StockDamagedCount);
    populateDateVsCountMapForStock(dateVsSpaq1StockLostList, dateVsSpaq1StockLostCount);
    populateDateVsCountMapForStock(dateVsSpaq2StockLostList, dateVsSpaq2StockLostCount);

    popoulateDateVsEntityCountMap(
      dateVsEntityVsCountMap,
      dateVsHouseholdMembersCount,
      dateVsHouseholdHeadsCount,
      dateVsAdministeredChilderenCount,
      dateVsRefusalCasesCount,
      dateVsSpaq1Count,
      dateVsSpaq2Count,
      dateVsSpaq1StockReceivedCount,
      dateVsSpaq2StockReceivedCount,
      dateVsSpaq1StockDamagedCount,
      dateVsSpaq2StockDamagedCount,
      dateVsSpaq1StockLostCount,
      dateVsSpaq2StockLostCount,
      uniqueDates,
    );
    dateVsEntityVsCountMap =
        sortMapByDateKeyAndRenameDate(dateVsEntityVsCountMap);
    dateVsEntityVsCountMap = addTotalEntryToMap(dateVsEntityVsCountMap);

    emit(SummaryReportDataState(data: dateVsEntityVsCountMap));
  }

  void getUniqueSetOfDates(
    Map<String, List<HouseholdMemberModel>> dateVsHouseholdMembersList,
    Map<String, List<HouseholdMemberModel>> dateVsHouseholdHeadsList,
    Map<String, List<TaskModel>> dateVsAdministeredChilderenList,
    Map<String, List<TaskModel>> dateVsRefusalCasesList,
    Map<String, List<TaskResourceModel>> dateVsSpaq1List,
    Map<String, List<TaskResourceModel>> dateVsSpaq2List,
    Map<String, List<StockModel>> dateVsSpaq1StockReceivedList,
    Map<String, List<StockModel>> dateVsSpaq2StockReceivedList,
    Map<String, List<StockModel>> dateVsSpaq1StockDamagedList,
    Map<String, List<StockModel>> dateVsSpaq2StockDamagedList,
    Map<String, List<StockModel>> dateVsSpaq1StockLostList,
    Map<String, List<StockModel>> dateVsSpaq2StockLostList,
    Set<String> uniqueDates,
  ) {
    uniqueDates.addAll(dateVsHouseholdMembersList.keys.toSet());
    uniqueDates.addAll(dateVsHouseholdHeadsList.keys.toSet());
    uniqueDates.addAll(dateVsAdministeredChilderenList.keys.toSet());
    uniqueDates.addAll(dateVsRefusalCasesList.keys.toSet());
    uniqueDates.addAll(dateVsSpaq1List.keys.toSet());
    uniqueDates.addAll(dateVsSpaq2List.keys.toSet());
    uniqueDates.addAll(dateVsSpaq1StockReceivedList.keys.toSet());
    uniqueDates.addAll(dateVsSpaq2StockReceivedList.keys.toSet());
    uniqueDates.addAll(dateVsSpaq1StockDamagedList.keys.toSet());
    uniqueDates.addAll(dateVsSpaq2StockDamagedList.keys.toSet());
    uniqueDates.addAll(dateVsSpaq1StockLostList.keys.toSet());
    uniqueDates.addAll(dateVsSpaq2StockLostList.keys.toSet());
  }

  void populateDateVsCountMap(
      Map<String, List> map, Map<String, int> dateVsCount) {
    map.forEach((key, value) {
      dateVsCount[key] = value.length;
    });
  }

  void populateDateVsCountMapForStock(
      Map<String, List<StockModel>> map, Map<String, int> dateVsCount) {
    map.forEach((key, stockList) {
      int totalQuantity = 0;
      for (var stock in stockList) {
        final quantity = stock.quantity;
        if (quantity != null) {
          totalQuantity += int.tryParse(quantity.toString()) ?? 0;
        }
      }
      dateVsCount[key] = totalQuantity;
    });
  }

  void popoulateDateVsEntityCountMap(
    Map<String, Map<String, int>> dateVsEntityVsCountMap,
    Map<String, int> dateVsHouseholdMembersCount,
    Map<String, int> dateVsHouseholdHeadsCount,
    Map<String, int> dateVsAdministeredChilderenCount,
    Map<String, int> dateVsRefusalCasesCount,
    Map<String, int> dateVsSpaq1Count,
    Map<String, int> dateVsSpaq2Count,
    Map<String, int> dateVsSpaq1StockReceivedCount,
    Map<String, int> dateVsSpaq2StockReceivedCount,
    Map<String, int> dateVsSpaq1StockDamagedCount,
    Map<String, int> dateVsSpaq2StockDamagedCount,
    Map<String, int> dateVsSpaq1StockLostCount,
    Map<String, int> dateVsSpaq2StockLostCount,
    Set<String> uniqueDates,
  ) {
    for (var date in uniqueDates) {
      Map<String, int> elementVsCount = {};
      
      // Existing counts
      if (dateVsHouseholdMembersCount.containsKey(date) &&
          dateVsHouseholdMembersCount[date] != null) {
        var count = dateVsHouseholdMembersCount[date];
        elementVsCount[Constants.registered] = count ?? 0;
      }
      if (dateVsHouseholdHeadsCount.containsKey(date) &&
          dateVsHouseholdHeadsCount[date] != null) {
        var count = dateVsHouseholdHeadsCount[date];
        elementVsCount[Constants.registeredHH] = count ?? 0;
      }
      if (dateVsAdministeredChilderenCount.containsKey(date) &&
          dateVsAdministeredChilderenCount[date] != null) {
        var count = dateVsAdministeredChilderenCount[date];
        elementVsCount[Constants.administered] = count ?? 0;
      }
      if (dateVsRefusalCasesCount.containsKey(date) &&
          dateVsRefusalCasesCount[date] != null) {
        var count = dateVsRefusalCasesCount[date];
        elementVsCount[Constants.refusals] = count ?? 0;
      }

      if (dateVsSpaq1Count.containsKey(date) &&
          dateVsSpaq1Count[date] != null) {
        var count = dateVsSpaq1Count[date];
        elementVsCount[Constants.tablet_3_11] = count ?? 0;
      }
      if (dateVsSpaq2Count.containsKey(date) &&
          dateVsSpaq2Count[date] != null) {
        var count = dateVsSpaq2Count[date];
        elementVsCount[Constants.tablet_12_59] = count ?? 0;
      }

      // Calculate remaining tablets for this day only (day-wise calculation)
      // Formula: received - (used + damaged + lost) for this specific day
      
      int receivedSpaq1Today = dateVsSpaq1StockReceivedCount[date] ?? 0;
      int receivedSpaq2Today = dateVsSpaq2StockReceivedCount[date] ?? 0;
      
      int spaq1Used = dateVsSpaq1Count[date] ?? 0;
      int spaq2Used = dateVsSpaq2Count[date] ?? 0;
      int spaq1Damaged = dateVsSpaq1StockDamagedCount[date] ?? 0;
      int spaq2Damaged = dateVsSpaq2StockDamagedCount[date] ?? 0;
      int spaq1Lost = dateVsSpaq1StockLostCount[date] ?? 0;
      int spaq2Lost = dateVsSpaq2StockLostCount[date] ?? 0;
      
      // Day-wise remaining = received today - (used + damaged + lost) today
      int spaq1Remaining = receivedSpaq1Today - (spaq1Used + spaq1Damaged + spaq1Lost);
      int spaq2Remaining = receivedSpaq2Today - (spaq2Used + spaq2Damaged + spaq2Lost);
      
      elementVsCount[Constants.remaining_tablet_3_11] = spaq1Remaining;
      elementVsCount[Constants.remaining_tablet_12_59] = spaq2Remaining;

      dateVsEntityVsCountMap[date] = elementVsCount;
    }
  }

  Map<String, Map<String, int>> sortMapByDateKeyAndRenameDate(
    Map<String, Map<String, int>> dateVsEntityVsCountMap,
  ) {
    final sortedEntries = dateVsEntityVsCountMap.entries.toList()
      ..sort((a, b) {
        final dateA = DateTime.parse(_toIsoFormat(a.key));
        final dateB = DateTime.parse(_toIsoFormat(b.key));
        return dateA.compareTo(dateB);
      });

    final Map<String, Map<String, int>> renamedMap = {};

    for (int i = 0; i < sortedEntries.length; i++) {
      final originalDate = sortedEntries[i].key;
      final newKey = '$originalDate Day${i + 1}';
      renamedMap[newKey] = sortedEntries[i].value;
    }

    return renamedMap;
  }

  Map<String, Map<String, int>> addTotalEntryToMap(
      Map<String, Map<String, int>> originalMap) {
    final Map<String, int> totalMap = {};

    // Get the last day's remaining values for remaining tablets
    Map<String, int>? lastDayData;
    if (originalMap.isNotEmpty) {
      // Find the last day entry (excluding 'Total' if it exists)
      final sortedEntries = originalMap.entries
          .where((entry) => entry.key != 'Total')
          .toList()
        ..sort((a, b) {
          final dateA = DateTime.parse(_toIsoFormat(a.key.split(' ')[0]));
          final dateB = DateTime.parse(_toIsoFormat(b.key.split(' ')[0]));
          return dateA.compareTo(dateB);
        });
      
      if (sortedEntries.isNotEmpty) {
        lastDayData = sortedEntries.last.value;
      }
    }

    for (final dayEntry in originalMap.entries) {
      final dayData = dayEntry.value;
      for (final entry in dayData.entries) {
        // For remaining tablets, use the last day's value instead of sum
        if (entry.key == Constants.remaining_tablet_3_11 || 
            entry.key == Constants.remaining_tablet_12_59) {
          if (lastDayData != null && lastDayData.containsKey(entry.key)) {
            totalMap[entry.key] = lastDayData[entry.key]!;
          } else {
            totalMap[entry.key] = 0;
          }
        } else {
          // For all other fields, sum them up
          totalMap.update(entry.key, (value) => value + entry.value,
              ifAbsent: () => entry.value);
        }
      }
    }

    // Create new map with 'Total' at the beginning
    final Map<String, Map<String, int>> newMap = {
      'Total': totalMap,
      ...originalMap,
    };

    return newMap;
  }

  /// Converts 'dd/MM/yyyy' to 'yyyy-MM-dd' for proper DateTime parsing
  String _toIsoFormat(String dateStr) {
    final parts = dateStr.split('/');
    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }

  Future<void> _handleLoadingEvent(
    SummaryReportLoadingEvent event,
    SummaryReportEmitter emit,
  ) async {
    emit(const SummaryReportLoadingState());
  }
}

@freezed
class SummaryReportEvent with _$SummaryReportEvent {
  const factory SummaryReportEvent.loadSummaryData({
    required String userId,
  }) = SummaryReportLoadDataEvent;

  const factory SummaryReportEvent.loading() = SummaryReportLoadingEvent;
}

@freezed
class SummaryReportState with _$SummaryReportState {
  const factory SummaryReportState.loading() = SummaryReportLoadingState;
  const factory SummaryReportState.empty() = SummaryReportEmptyState;

  const factory SummaryReportState.data({
    @Default({}) Map<String, Map<String, int>> data,
  }) = SummaryReportDataState;
}
