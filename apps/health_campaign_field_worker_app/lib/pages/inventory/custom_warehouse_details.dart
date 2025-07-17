import 'package:auto_route/auto_route.dart';
import 'package:collection/collection.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_scanner/blocs/scanner.dart';
import 'package:digit_scanner/pages/qr_scanner.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/input_wrapper.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:inventory_management/router/inventory_router.gm.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:digit_components/widgets/atoms/digit_dropdown.dart' as dropdown;

import 'package:inventory_management/utils/i18_key_constants.dart' as i18;
import '../../utils//i18_key_constants.dart' as i18_local;
import 'package:inventory_management/widgets/localized.dart';
import 'package:inventory_management/blocs/record_stock.dart';
import 'package:inventory_management/utils/utils.dart';
import 'package:inventory_management/widgets/back_navigation_help_header.dart';
import 'package:inventory_management/widgets/inventory/no_facilities_assigned_dialog.dart';
import '../../router/app_router.dart';
import '../../utils/constants.dart';
import '../../utils/extensions/extensions.dart';
import '../../utils/upper_case.dart';
import 'custom_facility_selection.dart';

@RoutePage()
class CustomWarehouseDetailsPage extends LocalizedStatefulWidget {
  const CustomWarehouseDetailsPage({
    super.key,
    super.appLocalizations,
  });

  @override
  State<CustomWarehouseDetailsPage> createState() =>
      CustomWarehouseDetailsPageState();
}

class CustomWarehouseDetailsPageState
    extends LocalizedState<CustomWarehouseDetailsPage> {
  static const _dateOfEntryKey = 'dateOfReceipt';
  static const _administrativeUnitKey = 'administrativeUnit';
  static const _warehouseKey = 'warehouse';
  static const _teamCodeKey = 'teamCode';
  static const _passageKey = 'passage';
  static const _jourKey = 'jour';
  
  bool deliveryTeamSelected = false;
  String? selectedFacilityId;
  TextEditingController controller1 = TextEditingController();

  @override
  void initState() {
    clearQRCodes();
    final stockState = context.read<RecordStockBloc>().state;
    setState(() {
      selectedFacilityId = stockState.primaryId;
    });
    super.initState();
  }

  FormGroup buildForm(bool isDistributor, RecordStockState stockState) =>
      fb.group(<String, Object>{
        _dateOfEntryKey: FormControl<DateTime>(value: DateTime.now()),
        _administrativeUnitKey: FormControl<String>(
          value: localizations
              .translate(InventorySingleton().boundary!.code ?? ''),
        ),
        _warehouseKey: FormControl<String>(
          validators: isDistributor ? [] : [Validators.required],
        ),
        _teamCodeKey: FormControl<String>(
          value: stockState.primaryId ??
              context.loggedInUser.userName.toString() +
                  Constants.pipeSeparator +
                  context.loggedInUserUuid,
          validators: isDistributor
              ? [
                  Validators.required,
                ]
              : [],
        ),
        _passageKey: FormControl<String>(),
        _jourKey: FormControl<String>(),
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recordStockBloc = BlocProvider.of<RecordStockBloc>(context);
    final textTheme = theme.digitTextTheme(context);
    final userUuid = context.loggedInUserUuid;

    return InventorySingleton().projectId.isEmpty
        ? Center(
            child: Text(localizations
                .translate(i18.stockReconciliationDetails.noProjectSelected)))
        : BlocConsumer<FacilityBloc, FacilityState>(
            listener: (context, state) {
              state.whenOrNull(
                empty: () =>
                    NoFacilitiesAssignedDialog.show(context, localizations),
              );
            },
            builder: (ctx, facilityState) {
              final facilities = facilityState.whenOrNull(
                    fetched: (facilities, allFacilities) {
                      // Start with the full list from 'allFacilities'
                      List<FacilityModel> filteredFacilityResult =
                          List.from(allFacilities); // Create a mutable copy

                      // Filter based on the boundary type of the selected project
                      // if boundary type is Country
                      if (ctx.selectedProject.address?.boundaryType ==
                          Constants.countryBoundaryLevel) {
                        filteredFacilityResult =
                            allFacilities // Filter the complete list
                                .where((element) =>
                                    element.usage == Constants.stateFacility)
                                .toList();
                        facilities = filteredFacilityResult.isEmpty
                            ? facilities
                            : filteredFacilityResult;
                        // if boundary type is State(ie Region)
                      } else if (ctx.selectedProject.address?.boundaryType ==
                          Constants.stateBoundaryLevel) {
                        filteredFacilityResult =
                            facilities // Filter the complete list
                                .where((element) =>
                                    element.usage == Constants.stateFacility)
                                .toList();
                        // Keep original if filter yields no results
                        facilities = filteredFacilityResult.isEmpty
                            ? facilities // Fallback to facilities if no match
                            : filteredFacilityResult;
                        // if boundary type is LGA(ie District)
                      } else if (ctx.selectedProject.address?.boundaryType ==
                          Constants.lgaBoundaryLevel) {
                        filteredFacilityResult =
                            facilities // Filter the complete list
                                .where(
                                  (element) =>
                                      element.usage == Constants.lgaFacility,
                                )
                                .toList();
                        facilities = filteredFacilityResult.isEmpty
                            ? facilities // Fallback to facilities if no match
                            : filteredFacilityResult;
                      }
                      // if boundary type is Health Facility or the default case if no other boundary type matches
                      else {
                        filteredFacilityResult =
                            facilities // Filter the complete list
                                .where(
                                  (element) =>
                                      element.usage == Constants.healthFacility,
                                )
                                .toList();
                        facilities = filteredFacilityResult.isEmpty
                            ? facilities // Fallback to allFacilities if no match
                            : filteredFacilityResult;
                      }

                      // Handle the Delivery Team (this logic seems separate from the main filtering)
                      final teamFacilities = [
                        FacilityModel(
                          id: 'Delivery Team',
                          name: 'Delivery Team',
                          // Consider adding a 'usage' here if it needs to be filtered or excluded
                          // usage: 'Delivery Team Special',
                        ),
                      ];

                      // Currently, teamFacilities.addAll(filteredResult); is commented out.
                      // If you want 'Delivery Team' to appear alongside the filtered list,
                      // you would uncomment that line or add 'filteredResult' to 'teamFacilities' here.
                      // teamFacilities.addAll(filteredResult); // Uncomment if you want Delivery Team + filtered facilities

                      // Decide which list to return based on the distributor status
                      return InventorySingleton().isDistributor! &&
                              !InventorySingleton().isWareHouseMgr!
                          ? teamFacilities // This list ONLY has 'Delivery Team' right now
                          : facilities; // This is your newly filtered list
                    },
                  ) ??
                  [];

              /*.  OLD LOGIC
                  if (ctx.selectedProject.address?.boundaryType ==
                      Constants.countryBoundaryLevel) {
                    List<FacilityModel> filteredFacilities = facilities
                        .where((element) =>
                            element.usage == Constants.stateFacility)
                        .toList();
                    facilities = filteredFacilities.isEmpty
                        ? facilities
                        : filteredFacilities;
                  } else if (ctx.selectedProject.address?.boundaryType ==
                      Constants.stateBoundaryLevel) {
                    List<FacilityModel> filteredFacilities = facilities
                        .where((element) =>
                            element.usage == Constants.stateFacility)
                        .toList();
                    facilities = filteredFacilities.isEmpty
                        ? facilities
                        : filteredFacilities;
                  } else if (ctx.selectedProject.address?.boundaryType ==
                      Constants.lgaBoundaryLevel) {
                    List<FacilityModel> filteredFacilities = facilities
                        .where(
                          (element) =>
                              element.usage == Constants.lgaFacility,
                        )
                        .toList();
                    facilities = filteredFacilities.isEmpty
                        ? facilities
                        : filteredFacilities;
                  } else {
                    List<FacilityModel> filteredFacilities = facilities
                        .where(
                          (element) =>
                              element.usage == Constants.healthFacility,
                        )
                        .toList();
                    facilities = filteredFacilities.isEmpty
                        ? facilities
                        : filteredFacilities;
                  }

                  final teamFacilities = [
                    FacilityModel(
                      id: 'Delivery Team',
                      name: 'Delivery Team',
                    ),
                  ];
                  // teamFacilities.addAll(
                  //   facilities,
                  // );

                  return InventorySingleton().isDistributor! &&
                          !InventorySingleton().isWareHouseMgr!
                      ? teamFacilities
                      : facilities;
                },
              ) ??
              [];*/
              final stockState = recordStockBloc.state;

              final entryType = stockState.entryType;
              String dateLabel;

              switch (entryType) {
                case StockRecordEntryType.receipt:
                  dateLabel = localizations.translate(
                    i18.warehouseDetails.dateOfReceipt,
                  );
                  break;
                case StockRecordEntryType.dispatch:
                  dateLabel = localizations.translate(
                    i18_local.warehouseDetailsShowcase.dateOfIssue,
                  );
                  break;
                case StockRecordEntryType.returned:
                  dateLabel = localizations.translate(
                    i18_local.warehouseDetailsShowcase.dateOfReturn,
                  );
                  break;
                case StockRecordEntryType.damaged:
                  dateLabel = localizations.translate(
                    i18.warehouseDetails.dateOfReceipt,
                  );
                  break;
                case StockRecordEntryType.loss:
                  dateLabel = localizations.translate(
                    i18.warehouseDetails.dateOfReceipt,
                  );
                  break;

                default:
                  dateLabel = '';
              }

              return Scaffold(
                body: GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                  },
                  child: BlocBuilder<DigitScannerBloc, DigitScannerState>(
                    builder: (context, scannerState) {
                      return ReactiveFormBuilder(
                        form: () => buildForm(
                            InventorySingleton().isDistributor! &&
                                !InventorySingleton().isWareHouseMgr!,
                            stockState),
                        builder: (context, form, child) {
                          // form.control(_teamCodeKey).value =
                          //     scannerState.qrCodes.isNotEmpty
                          //         ? scannerState.qrCodes.firstOrNull
                          //         : '';
                          final teamFacilities = [
                            FacilityModel(
                              id: 'Delivery Team',
                              name: 'Delivery Team',
                            ),
                          ];
                          if (InventorySingleton().isDistributor! &&
                              !InventorySingleton().isWareHouseMgr!) {
                            form.control(_warehouseKey).value = localizations
                                .translate('FAC_${teamFacilities.first.id}');
                            controller1.text = localizations
                                .translate('FAC_${teamFacilities.first.id}');
                            selectedFacilityId = teamFacilities.first.id;
                            deliveryTeamSelected = true;
                          }

                          return ScrollableContent(
                            header: const Column(children: [
                              BackNavigationHelpHeaderWidget(),
                            ]),
                            footer: SizedBox(
                              child: DigitCard(
                                  margin: const EdgeInsets.fromLTRB(
                                      0, spacer2, 0, 0),
                                  children: [
                                    ReactiveFormConsumer(
                                      builder: (context, form, child) {
                                        return DigitButton(
                                          type: DigitButtonType.primary,
                                          mainAxisSize: MainAxisSize.max,
                                          size: DigitButtonSize.large,
                                          label: localizations.translate(
                                            i18.householdDetails.actionLabel,
                                          ),
                                          onPressed: !form.valid
                                              ? () {}
                                              : () {
                                                  form.markAllAsTouched();

                                                  if (!form.valid) {
                                                    return;
                                                  }
                                                  final dateOfRecord = form
                                                      .control(_dateOfEntryKey)
                                                      .value as DateTime;

                                                  // final teamCode = form
                                                  //     .control(_teamCodeKey)
                                                  final teamCode =
                                                      (context.loggedInUser
                                                                  .userName
                                                                  .toString() +
                                                              Constants
                                                                  .pipeSeparator +
                                                              context
                                                                  .loggedInUserUuid)
                                                          as String?;
                                                  final uuidRegex = RegExp(
                                                      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
                                                  final trainingRegex =
                                                      RegExp(r'^cps-f\d{5}$');
                                                  final productionRegex =
                                                      RegExp(
                                                          r'^CPS26-(\d{6})$');
                                                  /* if (deliveryTeamSelected &&
                                                      (teamCode == null ||
                                                          !uuidRegex.hasMatch(
                                                              teamCode) && !trainingRegex.hasMatch(
                                                              teamCode) && !productionRegex.hasMatch(
                                                              teamCode))) {
                                                    Toast.showToast(
                                                      context,
                                                      type: ToastType.error,
                                                      message: localizations
                                                          .translate(i18_local
                                                              .stockReconciliationDetails
                                                              .qrCodeInvalidFormat),
                                                    );
                                                    return;
                                                   }*/

                                                  final facility =
                                                      deliveryTeamSelected
                                                          ? FacilityModel(
                                                              id: teamCode ??
                                                                  'Delivery Team',
                                                            )
                                                          : selectedFacilityId !=
                                                                  null
                                                              ? FacilityModel(
                                                                  id: selectedFacilityId
                                                                      .toString(),
                                                                )
                                                              : null;

                                                  context
                                                      .read<DigitScannerBloc>()
                                                      .add(
                                                        const DigitScannerEvent
                                                            .handleScanner(
                                                            qrCode: [],
                                                            barCode: []),
                                                      );
                                                  if (facility == null) {
                                                    Toast.showToast(
                                                      type: ToastType.error,
                                                      context,
                                                      message: localizations
                                                          .translate(
                                                        i18.stockDetails
                                                            .facilityRequired,
                                                      ),
                                                    );
                                                  } else if (deliveryTeamSelected &&
                                                      (teamCode == null ||
                                                          teamCode
                                                              .trim()
                                                              .isEmpty)) {
                                                    Toast.showToast(
                                                      context,
                                                      type: ToastType.error,
                                                      message: localizations
                                                          .translate(
                                                        i18.stockDetails
                                                            .teamCodeRequired,
                                                      ),
                                                    );
                                                  } else {
                                                    // Get passage and jour values from form to pass to the next page
                                                    final passageValue = form.control(_passageKey).value as String?;
                                                    final jourValue = form.control(_jourKey).value as String?;
                                                    
                                                    recordStockBloc.add(
                                                      RecordStockSaveTransactionDetailsEvent(
                                                        dateOfRecord:
                                                            dateOfRecord,
                                                        facilityModel: InventorySingleton()
                                                                    .isDistributor! &&
                                                                !InventorySingleton()
                                                                    .isWareHouseMgr!
                                                            ? FacilityModel(
                                                                id: teamCode
                                                                    .toString(),
                                                              )
                                                            : facility,
                                                        primaryId: facility
                                                                    .id ==
                                                                "Delivery Team"
                                                            ? (teamCode ?? '')
                                                                .split(Constants
                                                                    .pipeSeparator)
                                                                .last
                                                            : facility.id,
                                                        primaryType: (InventorySingleton()
                                                                        .isDistributor! &&
                                                                    !InventorySingleton()
                                                                        .isWareHouseMgr! &&
                                                                    deliveryTeamSelected) ||
                                                                deliveryTeamSelected
                                                            ? "STAFF"
                                                            : "WAREHOUSE",
                                                      ),
                                                    );
                                                    // Store values in temporary storage for access in the next page                                 
                                                    context.router.push(
                                                      CustomStockDetailsRoute(
                                                        passage: passageValue,
                                                        jour: jourValue,
                                                      
                                                      ),
                                                    );
                                                  }
                                                },
                                        );
                                      },
                                    ),
                                  ]),
                            ),
                            children: [
                              DigitCard(
                                  margin: const EdgeInsets.all(spacer2),
                                  children: [
                                    Text(
                                      InventorySingleton().isDistributor! &&
                                              !InventorySingleton()
                                                  .isWareHouseMgr!
                                          ? localizations.translate(
                                              i18.stockDetails
                                                  .transactionDetailsLabel,
                                            )
                                          : localizations.translate(
                                              i18.warehouseDetails
                                                  .warehouseDetailsLabel,
                                            ),
                                      style: textTheme.headingXl,
                                    ),
                                    ReactiveWrapperField(
                                        formControlName: _dateOfEntryKey,
                                        builder: (field) {
                                          return InputField(
                                            inputFormatters: [
                                              UpperCaseTextFormatter(),
                                            ],
                                            type: InputType.date,
                                            label: dateLabel,
                                            confirmText:
                                                localizations.translate(
                                              i18.common.coreCommonOk,
                                            ),
                                            cancelText: localizations.translate(
                                              i18.common.coreCommonCancel,
                                            ),
                                            initialValue: DateFormat(
                                                    'd MMMM yyyy')
                                                .format(field.control.value),
                                            readOnly: false,
                                            firstDate: DateTime.now().subtract(
                                                const Duration(days: 15)),
                                            lastDate: DateTime.now(),
                                          );
                                        }),
                                    ReactiveWrapperField(
                                        formControlName: _administrativeUnitKey,
                                        builder: (field) {
                                          return InputField(
                                            inputFormatters: [
                                              UpperCaseTextFormatter(),
                                            ],
                                            isRequired: true,
                                            type: InputType.text,
                                            label: localizations.translate(
                                              i18.warehouseDetails
                                                  .administrativeUnit,
                                            ),
                                            initialValue: field.control.value,
                                            readOnly: true,
                                          );
                                        }),
                                    InkWell(
                                      onTap: () async {
                                        clearQRCodes();
                                        form.control(_teamCodeKey).value = '';

                                        final facility =
                                            await Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                CustomInventoryFacilitySelectionPage(
                                              facilities: facilities,
                                            ),
                                          ),
                                        );

                                        if (facility == null) return;
                                        form.control(_warehouseKey).value =
                                            localizations.translate(
                                                'FAC_${facility.id}');
                                        controller1.text = localizations
                                            .translate('FAC_${facility.id}');

                                        setState(() {
                                          selectedFacilityId = facility.id;
                                        });
                                        if (facility.id == 'Delivery Team') {
                                          setState(() {
                                            deliveryTeamSelected = true;
                                          });
                                        } else {
                                          setState(() {
                                            deliveryTeamSelected = false;
                                          });
                                        }
                                      },
                                      child: IgnorePointer(
                                        child: ReactiveWrapperField(
                                            formControlName: _warehouseKey,
                                            validationMessages: {
                                              'required': (object) =>
                                                  localizations.translate(
                                                    '${i18.individualDetails.nameLabelText}_IS_REQUIRED',
                                                  ),
                                            },
                                            showErrors: (control) =>
                                                control.invalid &&
                                                control.touched,
                                            builder: (field) {
                                              return InputField(
                                                inputFormatters: [
                                                  UpperCaseTextFormatter(),
                                                ],
                                                type: InputType.search,
                                                label: localizations.translate(
                                                  i18.stockReconciliationDetails
                                                      .facilityLabel,
                                                ),
                                                controller: controller1,
                                                isRequired: true,
                                                errorMessage: field.errorText,
                                                onChange: (value) {
                                                  field.control.markAsTouched();
                                                },
                                              );
                                            }),
                                      ),
                                    ),
                                    if (deliveryTeamSelected)
                                      ReactiveWrapperField(
                                          formControlName: _teamCodeKey,
                                          builder: (field) {
                                            return InputField(
                                              inputFormatters: [
                                                UpperCaseTextFormatter(),
                                              ],
                                              readOnly: true,
                                              keyboardType: TextInputType.none,
                                              type: InputType.search,
                                              label: localizations.translate(
                                                i18.stockReconciliationDetails
                                                    .teamCodeLabel,
                                              ),
                                              initialValue: context
                                                      .loggedInUser.userName
                                                      .toString() +
                                                  Constants.pipeSeparator +
                                                  context.loggedInUserUuid,
                                              isRequired: deliveryTeamSelected,
                                              suffixIcon: Icons.qr_code_2,
                                              onSuffixTap: null,
                                            );
                                          }),
                                    if (deliveryTeamSelected)
                                      dropdown.DigitDropdown<String>(
                                        label: localizations.translate(
                                          i18_local.stockDetails.passageValueLabel,
                                        ),
                                        valueMapper: (value) => value,
                                        initialValue: form.control(_passageKey).value,
                                        menuItems: [
                                          localizations.translate(
                                            i18_local.stockDetails.passageValueOne,
                                          ),
                                          localizations.translate(
                                            i18_local.stockDetails.passageValueTwo,
                                          ),
                                          localizations.translate(
                                            i18_local.stockDetails.passageValueThree,
                                          ),
                                          localizations.translate(
                                            i18_local.stockDetails.passageValueFour,
                                          ),
                                          localizations.translate(
                                            i18_local.stockDetails.passageValueFive,
                                          ),
                                          
                                        ],
                                        formControlName: _passageKey,
                                        onChanged: (value) {
                                          form.control(_passageKey).value = value;
                                        },
                                      ),

                                      if (deliveryTeamSelected)
                                      dropdown.DigitDropdown<String>(
                                        label: localizations.translate(
                                          i18_local.stockDetails.jourValueLabel,
                                        ),
                                        valueMapper: (value) => value,
                                        initialValue: form.control(_jourKey).value,
                                        menuItems:  [
                                         localizations.translate(i18_local.stockDetails.jourValueOne),
                                          localizations.translate(i18_local.stockDetails.jourValueTwo),
                                          localizations.translate(i18_local.stockDetails.jourValueThree),
                                          localizations.translate(i18_local.stockDetails.jourValueFour),
                                          localizations.translate(i18_local.stockDetails.jourValueFive),
                                        ],
                                        formControlName: _jourKey,
                                        onChanged: (value) {
                                          form.control(_jourKey).value = value;
                                        },
                                      ),  
                                  ]
                                  
                                  ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              );
            },
          );
  }

  void clearQRCodes() {
    context.read<DigitScannerBloc>().add(const DigitScannerEvent.handleScanner(
          barCode: [],
          qrCode: [],
        ));
  }
}
