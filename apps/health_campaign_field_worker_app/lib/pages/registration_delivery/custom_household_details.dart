import 'package:auto_route/auto_route.dart';
import 'package:digit_data_model/data_model.dart';
import 'package:digit_data_model/models/entities/household_type.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/widgets/atoms/text_block.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_campaign_field_worker_app/widgets/custom_back_navigation.dart';
import 'package:intl/intl.dart';
import 'package:reactive_forms/reactive_forms.dart';
import 'package:registration_delivery/blocs/household_overview/household_overview.dart';
import 'package:registration_delivery/blocs/search_households/search_households.dart';
import 'package:registration_delivery/models/entities/additional_fields_type.dart';
import 'package:registration_delivery/utils/extensions/extensions.dart';

import 'package:registration_delivery/models/entities/household.dart';
import 'package:registration_delivery/router/registration_delivery_router.gm.dart';
import 'package:registration_delivery/utils/constants.dart';
import 'package:registration_delivery/utils/i18_key_constants.dart' as i18;
import '../../utils/i18_key_constants.dart' as i18_local;
import 'package:registration_delivery/utils/utils.dart';
import 'package:registration_delivery/widgets/back_navigation_help_header.dart';
import 'package:registration_delivery/widgets/localized.dart';
import 'package:registration_delivery/widgets/showcase/config/showcase_constants.dart';
import 'package:registration_delivery/widgets/showcase/showcase_button.dart';

import '../../blocs/registration_delivery/custom_beneficairy_registration.dart';
import '../../models/entities/identifier_types.dart';
import '../../router/app_router.dart';
import '../../utils/registration_delivery/registration_delivery_utils.dart';

@RoutePage()
class CustomHouseHoldDetailsPage extends LocalizedStatefulWidget {
  const CustomHouseHoldDetailsPage({
    super.key,
    super.appLocalizations,
  });

  @override
  State<CustomHouseHoldDetailsPage> createState() =>
      CustomHouseHoldDetailsPageState();
}

class CustomHouseHoldDetailsPageState
    extends LocalizedState<CustomHouseHoldDetailsPage> {
  static const _dateOfRegistrationKey = 'dateOfRegistration';
  static const _memberCountKey = 'memberCount';
  static const _children0To59Key = 'children0to59';
  static const _children0To11Key = 'children0to11';
  static const _children12To59Key = 'children12to59';
  static const _currentCycleKey = 'currentCycle';
   final currentCycle =
    RegistrationDeliverySingleton().projectType?.cycles?.firstWhere(
      (e) =>
        (e.startDate) < DateTime.now().millisecondsSinceEpoch &&
        (e.endDate) > DateTime.now().millisecondsSinceEpoch,
      );
      
  

  // Define controllers
  final TextEditingController _pregnantWomenController =
      TextEditingController();
  final TextEditingController _childrenController = TextEditingController();
  final TextEditingController _memberController = TextEditingController();

  @override
  void dispose() {
    _pregnantWomenController.dispose();
    _childrenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<CustomBeneficiaryRegistrationBloc>();
    final router = context.router;
    final textTheme = theme.digitTextTheme(context);
    final bool isCommunity = RegistrationDeliverySingleton().householdType ==
        HouseholdType.community;

    Future<String> generateHouseholdId() async {
      final userId = RegistrationDeliverySingleton().loggedInUserUuid;

      final boundaryBloc = context.read<BoundaryBloc>().state;
      final code = boundaryBloc.boundaryList.first.code;
      final bname = boundaryBloc.boundaryList.first.name;

      final locality = (code == null || bname == null)
          ? null
          : LocalityModel(code: code, name: bname);

      final localityCode = locality!.code;

      final ids = await UniqueIdGeneration().generateUniqueId(
        localityCode: localityCode,
        loggedInUserId: userId!,
        returnCombinedIds: false,
      );

      return ids.first;
    }

    return Scaffold(
      body: ReactiveFormBuilder(
        form: () => buildForm(bloc.state),
        builder: (context, form, child) {
          int memberCount = form.control(_memberCountKey).value;
          final bool isCommunity =
              RegistrationDeliverySingleton().householdType ==
                  HouseholdType.community;
          if (isCommunity) {
            _memberController.text =
                form.control(_memberCountKey).value.toString();
          }
          return BlocConsumer<CustomBeneficiaryRegistrationBloc,
              BeneficiaryRegistrationState>(
            listener: (context, state) {
              if (state is BeneficiaryRegistrationPersistedState &&
                  state.isEdit) {
                final overviewBloc = context.read<HouseholdOverviewBloc>();

                overviewBloc.add(
                  HouseholdOverviewReloadEvent(
                    projectId:
                        RegistrationDeliverySingleton().projectId.toString(),
                    projectBeneficiaryType:
                        RegistrationDeliverySingleton().beneficiaryType ??
                            BeneficiaryType.household,
                  ),
                );
                HouseholdMemberWrapper memberWrapper =
                    overviewBloc.state.householdMemberWrapper;
                final route = router.parent() as StackRouter;
                route.popUntilRouteWithName(SearchBeneficiaryRoute.name);
                route.push(BeneficiaryWrapperRoute(wrapper: memberWrapper));
              }
            },
            builder: (context, registrationState) {
              return ScrollableContent(
                header: const Column(children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: spacer2),
                    child: CustomBackNavigationHelpHeaderWidget(
                      showHelp: false,
                    ),
                  ),
                ]),
                enableFixedDigitButton: true,
                footer: DigitCard(
                    margin: const EdgeInsets.only(top: spacer2),
                    children: [
                      DigitButton(
                        label: registrationState.mapOrNull(
                              editHousehold: (value) => localizations
                                  .translate(i18.common.coreCommonSave),
                            ) ??
                            localizations
                                .translate(i18.householdDetails.actionLabel),
                        type: DigitButtonType.primary,
                        size: DigitButtonSize.large,
                        mainAxisSize: MainAxisSize.max,
                        onPressed: () {
                          form.markAllAsTouched();
                          if (!form.valid) return;

                          final memberCount =
                              form.control(_memberCountKey).value as int;

                          final dateOfRegistration = form
                              .control(_dateOfRegistrationKey)
                              .value as DateTime;
                          //  Read new values from form

                          final children0to59 =
                              form.control(_children0To59Key).value as int? ??
                                  0;
                          final children0to11 =
                              form.control(_children0To11Key).value as int? ??
                                  0;
                          final children12to59 =
                              form.control(_children12To59Key).value as int? ??
                                  0;

                          // Prepare additional fields
                          final additionalFieldstoSave = [
                            AdditionalField(
                                IdentifierTypes.uniqueBeneficiaryID.toValue(),
                                ''), // Placeholder for generated ID
                            AdditionalField(_children0To59Key, children0to59),
                            AdditionalField(_children0To11Key, children0to11),
                            AdditionalField(_children12To59Key, children12to59),
                          ];

                          registrationState.maybeWhen(
                            orElse: () {
                              return;
                            },
                            create: (
                              addressModel,
                              householdModel,
                              individualModel,
                              projectBeneficiaryModel,
                              registrationDate,
                              searchQuery,
                              loading,
                              isHeadOfHousehold,
                            ) async {
                              final String householdid =
                                  await generateHouseholdId();

                              // Update householdid in additional fields ***
                              additionalFieldstoSave[0] = AdditionalField(
                                IdentifierTypes.uniqueBeneficiaryID.toValue(),
                                householdid,
                              );
                              var household = householdModel;

                              household ??= HouseholdModel(
                                tenantId:
                                    RegistrationDeliverySingleton().tenantId,
                                clientReferenceId:
                                    householdModel?.clientReferenceId ??
                                        IdGen.i.identifier,
                                rowVersion: 1,
                                clientAuditDetails: ClientAuditDetails(
                                  createdBy: RegistrationDeliverySingleton()
                                      .loggedInUserUuid!,
                                  createdTime: context.millisecondsSinceEpoch(),
                                  lastModifiedBy:
                                      RegistrationDeliverySingleton()
                                          .loggedInUserUuid,
                                  lastModifiedTime:
                                      context.millisecondsSinceEpoch(),
                                ),
                                auditDetails: AuditDetails(
                                  createdBy: RegistrationDeliverySingleton()
                                      .loggedInUserUuid!,
                                  createdTime: context.millisecondsSinceEpoch(),
                                  lastModifiedBy:
                                      RegistrationDeliverySingleton()
                                          .loggedInUserUuid,
                                  lastModifiedTime:
                                      context.millisecondsSinceEpoch(),
                                ),
                              );

                              household = household.copyWith(
                                  memberCount: memberCount,
                                  rowVersion: 1,
                                  tenantId:
                                      RegistrationDeliverySingleton().tenantId,
                                  clientReferenceId:
                                      householdModel?.clientReferenceId ??
                                          IdGen.i.identifier,
                                  clientAuditDetails: ClientAuditDetails(
                                    createdBy: RegistrationDeliverySingleton()
                                        .loggedInUserUuid
                                        .toString(),
                                    createdTime:
                                        context.millisecondsSinceEpoch(),
                                    lastModifiedBy:
                                        RegistrationDeliverySingleton()
                                            .loggedInUserUuid
                                            .toString(),
                                    lastModifiedTime:
                                        context.millisecondsSinceEpoch(),
                                  ),
                                  auditDetails: AuditDetails(
                                    createdBy: RegistrationDeliverySingleton()
                                        .loggedInUserUuid
                                        .toString(),
                                    createdTime:
                                        context.millisecondsSinceEpoch(),
                                    lastModifiedBy:
                                        RegistrationDeliverySingleton()
                                            .loggedInUserUuid
                                            .toString(),
                                    lastModifiedTime:
                                        context.millisecondsSinceEpoch(),
                                  ),
                                  address: addressModel,
                                  // id: householdid,
                                  additionalFields: HouseholdAdditionalFields(
                                      version: 1,
                                      fields: additionalFieldstoSave));

                              bloc.add(
                                BeneficiaryRegistrationSaveHouseholdDetailsEvent(
                                  household: household,
                                  registrationDate: dateOfRegistration,
                                ),
                              );
                              context.router.push(
                                CustomIndividualDetailsRoute(
                                    isHeadOfHousehold: true),
                              );
                            },
                            editHousehold: (
                              addressModel,
                              householdModel,
                              individuals,
                              registrationDate,
                              projectBeneficiaryModel,
                              loading,
                              isHeadOfHousehold,
                            ) {
                              // In edit mode, we must preserve the existing beneficiary ID
                              final beneficiaryId =
                                  householdModel.additionalFields?.fields
                                          .firstWhere(
                                            (field) =>
                                                field.key ==
                                                IdentifierTypes
                                                    .uniqueBeneficiaryID
                                                    .toValue(),
                                            orElse: () =>
                                                const AdditionalField('', ''),
                                          )
                                          .value ??
                                      '';

                              // Re-create the list of fields to save, ensuring the existing ID is used
                              final fieldsToSave = [
                                AdditionalField(
                                    IdentifierTypes.uniqueBeneficiaryID
                                        .toValue(),
                                    beneficiaryId),
                                AdditionalField(
                                    _children0To59Key, children0to59),
                                AdditionalField(
                                    _children0To11Key, children0to11),
                                AdditionalField(
                                    _children12To59Key, children12to59),
                              ];

                              var household = householdModel.copyWith(
                                  memberCount: memberCount,
                                  address: addressModel,
                                  clientAuditDetails: (householdModel
                                                  .clientAuditDetails
                                                  ?.createdBy !=
                                              null &&
                                          householdModel.clientAuditDetails
                                                  ?.createdTime !=
                                              null)
                                      ? ClientAuditDetails(
                                          createdBy: householdModel
                                              .clientAuditDetails!.createdBy,
                                          createdTime: householdModel
                                              .clientAuditDetails!.createdTime,
                                          lastModifiedBy:
                                              RegistrationDeliverySingleton()
                                                  .loggedInUserUuid,
                                          lastModifiedTime: DateTime.now()
                                              .millisecondsSinceEpoch,
                                        )
                                      : null,
                                  rowVersion: householdModel.rowVersion,
                                  additionalFields: HouseholdAdditionalFields(
                                      version: householdModel
                                              .additionalFields?.version ??
                                          1,
                                      fields: fieldsToSave
                                      //[TODO: Use pregnant women form value based on project config
                                      ));

                              bloc.add(
                                BeneficiaryRegistrationUpdateHouseholdDetailsEvent(
                                  household: household.copyWith(
                                    clientAuditDetails: (addressModel
                                                    .clientAuditDetails
                                                    ?.createdBy !=
                                                null &&
                                            addressModel.clientAuditDetails
                                                    ?.createdTime !=
                                                null)
                                        ? ClientAuditDetails(
                                            createdBy: addressModel
                                                .clientAuditDetails!.createdBy,
                                            createdTime: addressModel
                                                .clientAuditDetails!
                                                .createdTime,
                                            lastModifiedBy:
                                                RegistrationDeliverySingleton()
                                                    .loggedInUserUuid,
                                            lastModifiedTime: context
                                                .millisecondsSinceEpoch(),
                                          )
                                        : null,
                                  ),
                                  addressModel: addressModel.copyWith(
                                    clientAuditDetails: (addressModel
                                                    .clientAuditDetails
                                                    ?.createdBy !=
                                                null &&
                                            addressModel.clientAuditDetails
                                                    ?.createdTime !=
                                                null)
                                        ? ClientAuditDetails(
                                            createdBy: addressModel
                                                .clientAuditDetails!.createdBy,
                                            createdTime: addressModel
                                                .clientAuditDetails!
                                                .createdTime,
                                            lastModifiedBy:
                                                RegistrationDeliverySingleton()
                                                    .loggedInUserUuid,
                                            lastModifiedTime: context
                                                .millisecondsSinceEpoch(),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ]),
                slivers: [
                  SliverToBoxAdapter(
                    child: DigitCard(
                        margin: const EdgeInsets.all(spacer2),
                        children: [
                          DigitTextBlock(
                            padding: EdgeInsets.zero,
                            heading: (isCommunity)
                                ? localizations.translate(
                                    i18.householdDetails.clfDetailsLabel,
                                  )
                                : localizations.translate(
                                    i18_local.householdDetails
                                        .dateOfHouseholdRegistrationLabelUpdate,
                                  ),
                            headingStyle: textTheme.headingXl
                                .copyWith(color: theme.colorTheme.text.primary),
                          ),
                          householdDetailsShowcaseData.dateOfRegistration
                              .buildWith(
                            child: ReactiveWrapperField(
                              formControlName: _dateOfRegistrationKey,
                              builder: (field) => LabeledField(
                                label: localizations.translate(
                                  i18.householdDetails.dateOfRegistrationLabel,
                                ),
                                child: AbsorbPointer(
                                  absorbing: false,
                                  child: DigitDateFormInput(
                                    readOnly: false,
                                    confirmText: localizations.translate(
                                      i18.common.coreCommonOk,
                                    ),
                                    cancelText: localizations.translate(
                                      i18.common.coreCommonCancel,
                                    ),
                                    initialValue: DateFormat(
                                      'd MMMM yyyy',
                                    )
                                        .format(form
                                            .control(_dateOfRegistrationKey)
                                            .value)
                                        .toString(),
                                    firstDate: DateTime.now().subtract(
                                        const Duration(
                                            days: 15)), // Last 15 days
                                    lastDate: DateTime.now(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // householdDetailsShowcaseData
                          //     .numberOfMembersLivingInHousehold
                          //     .buildWith(
                          //   child: ReactiveWrapperField(
                          //     formControlName: _memberCountKey,
                          //     builder: (field) => LabeledField(
                          //       label: (RegistrationDeliverySingleton()
                          //                   .householdType ==
                          //               HouseholdType.community)
                          //           ? localizations.translate(
                          //               i18.householdDetails
                          //                   .noOfMembersCountCLFLabel,
                          //             )
                          //           : localizations.translate(
                          //               i18.householdDetails
                          //                   .noOfMembersCountLabel,
                          //             ),
                          //       isRequired: true,
                          //       child: DigitNumericFormInput(
                          //         inputFormatters: [
                          //           FilteringTextInputFormatter.digitsOnly
                          //         ],
                          //         minValue: 1,
                          //         maxValue: !isCommunity ? 30 : 1000000,
                          //         maxLength: 5,
                          //         step: 1,
                          //         editable: isCommunity,
                          //         controller:
                          //             isCommunity ? _memberController : null,
                          //         initialValue: isCommunity
                          //             ? null
                          //             : form
                          //                 .control(_memberCountKey)
                          //                 .value
                          //                 .toString(),
                          //         onChange: (value) {
                          //           if (value.isEmpty) {
                          //             _memberController.text = '1';
                          //             form.control(_memberCountKey).value = 1;
                          //             return;
                          //           }
                          //           // Remove leading zeros
                          //           String newValue = value;

                          //           if (value == '0' && isCommunity) {
                          //             newValue = '1';
                          //           }
                          //           _memberController.text = newValue;
                          //           form.control(_memberCountKey).value =
                          //               int.parse(newValue);

                          //           int memberCount =
                          //               form.control(_memberCountKey).value;
                          //           // if (memberCount <=
                          //           //     pregnantWomen + children) {
                          //           //   form.control(_memberCountKey).value =
                          //           //       (children + pregnantWomen);
                          //           //   _memberController.text =
                          //           //       (children + pregnantWomen).toString();
                          //           // }
                          //         },
                          //       ),
                          //     ),
                          //   ),
                          // ),
                          //[TODO: Use pregnant women form value based on project config
                          // A - Number of children 0 to 59 months

                          ReactiveWrapperField(
                            formControlName: _children0To59Key,
                            validationMessages: {
                              'totalMismatch': (error) =>
                                  localizations.translate(
                                    i18_local.householdDetails
                                        .totalChildrenCountMismatchError,
                                  ),
                              // "Total must be the sum of the two fields below",
                            },
                            builder: (field) {
                              return LabeledField(
                                label: localizations.translate(
                                  i18_local.householdDetails
                                      .numberOfChildren0To59MonthsLabel,
                                ),
                                // label: "Number of children 0 to 59 months (A)",
                                isRequired: true,
                                child: DigitNumericFormInput(
                                  initialValue:
                                      (field.control.value ?? 0).toString(),
                                  step: 1,
                                  minValue: 0,
                                  errorMessage: field.errorText,
                                  onChange: (value) {
                                    field.control.value =
                                        int.tryParse(value) ?? 0;
                                    // This line tells the form to re-run all its validators
                                    field.control.parent
                                        ?.updateValueAndValidity();
                                    form.control(_memberCountKey).value =
                                            field.control.value ?? 0;
                                  },
                                ),
                              );
                            },
                          ),

                          // B - Number of children 0 to 11 months

                          ReactiveWrapperField(
                            formControlName: _children0To11Key,
                            builder: (field) {
                              return LabeledField(
                                label: localizations.translate(
                                  i18_local.householdDetails
                                      .numberOfChildren0To11MonthsLabel,
                                ),
                                // label: "Number of children 0 to 11 months (B)",
                                isRequired: true,
                                child: DigitNumericFormInput(
                                  initialValue:
                                      (field.control.value ?? 0).toString(),
                                  step: 1,
                                  minValue: 0,
                                  onChange: (value) {
                                    field.control.value =
                                        int.tryParse(value) ?? 0;
                                    // This line tells the form to re-run all its validators
                                    field.control.parent
                                        ?.updateValueAndValidity();
                                  },
                                ),
                              );
                            },
                          ),

                          // C - Number of children 12 to 59 months

                          ReactiveWrapperField(
                            formControlName: _children12To59Key,
                            builder: (field) {
                              return LabeledField(
                                label: localizations.translate(
                                  i18_local.householdDetails
                                      .numberOfChildren12To59MonthsLabel,
                                ),
                                // label: "Number of children 12 to 59 months (C)",
                                isRequired: true,
                                child: DigitNumericFormInput(
                                  initialValue:
                                      (field.control.value ?? 0).toString(),
                                  step: 1,
                                  minValue: 0,
                                  onChange: (value) {
                                    field.control.value =
                                        int.tryParse(value) ?? 0;
                                    // This line tells the form to re-run all its validators
                                    field.control.parent
                                        ?.updateValueAndValidity();
                                  },
                                ),
                              );
                            },
                          ),
                          ReactiveWrapperField(
                            formControlName: _currentCycleKey,
                            builder: (field) {
                              return LabeledField(
                                label: localizations.translate(
                                  i18.beneficiaryDetails.currentCycleLabel,
                                ),
                                // label: "Number of children 12 to 59 months (C)",
                                
                                child:  DigitTextFormInput(
                                  errorMessage: field.errorText,
                                  readOnly: true,
                                  initialValue: form
                                      .control(_currentCycleKey)
                                      .value,
                                ),
                              );
                            },
                          ),

                          
                        ]),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // *** Custom Validator ***
  /// Validator that checks if the total number of children is the sum of the sub-categories.
  Map<String, dynamic>? _validateChildCounts(AbstractControl<dynamic> control) {
    final formGroup = control as FormGroup;
    final a = formGroup.control(_children0To59Key).value as int? ?? 0;
    final b = formGroup.control(_children0To11Key).value as int? ?? 0;
    final c = formGroup.control(_children12To59Key).value as int? ?? 0;

    // The validation fails if A is not equal to B + C
    if (a != (b + c)) {
      // Attaching the error to the 'A' field so the message appears there
      formGroup.control(_children0To59Key).setErrors({'totalMismatch': true});
    } else {
      // If it's valid, clear the error
      formGroup.control(_children0To59Key).removeError('totalMismatch');
    }

    return null;
  }

  FormGroup buildForm(BeneficiaryRegistrationState state) {
    final household = state.mapOrNull(editHousehold: (value) {
      return value.householdModel;
    }, create: (value) {
      return value.householdModel;
    });

    final registrationDate = state.mapOrNull(
      editHousehold: (value) {
        return value.registrationDate;
      },
      create: (value) => DateTime.now(),
    );

    //  Get initial values for children fields for editing
    final additionalFields = household?.additionalFields?.fields;

    int? getFieldValue(String key) {
      final field = additionalFields?.firstWhere((f) => f.key == key,
          orElse: () => AdditionalField(key, null));
      if (field?.value != null && field!.value is int) {
        return field.value;
      } else if (field?.value != null && field!.value is String) {
        return int.tryParse(field.value as String);
      }
      return 0; // Default to 0 if not found or invalid
    }

    final initialChildren0to59 = getFieldValue(_children0To59Key);
    final initialChildren0to11 = getFieldValue(_children0To11Key);
    final initialChildren12to59 = getFieldValue(_children12To59Key);

    // Get current cycle name
    final currentCycleName = currentCycle?.id.toString() ?? 'No active cycle';

    return fb.group(<String, Object>{
      _dateOfRegistrationKey:
          FormControl<DateTime>(value: registrationDate, validators: []),
      _memberCountKey: FormControl<int>(
        value: household?.memberCount ?? 1,
      ),
      //  Add controls to the form group
      _children0To59Key: FormControl<int>(
          value: initialChildren0to59, validators: [Validators.required]),
      _children0To11Key: FormControl<int>(
          value: initialChildren0to11, validators: [Validators.required]),
      _children12To59Key: FormControl<int>(
          value: initialChildren12to59, validators: [Validators.required]),
      _currentCycleKey: FormControl<String>(
          value: currentCycleName),
    }, [
      //  Apply the custom validator to the whole form group
      Validators.delegate((control) => _validateChildCounts(control)),
    ]);
  }
}
