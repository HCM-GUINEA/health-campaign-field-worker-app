import 'package:auto_route/auto_route.dart';
import 'package:digit_ui_components/digit_components.dart';
import 'package:digit_ui_components/theme/digit_extended_theme.dart';
import 'package:digit_ui_components/utils/date_utils.dart';
import 'package:digit_ui_components/widgets/atoms/label_value_list.dart';
import 'package:digit_ui_components/widgets/atoms/pop_up_card.dart';
import 'package:digit_ui_components/widgets/molecules/digit_card.dart';
import 'package:digit_ui_components/widgets/molecules/label_value_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:registration_delivery/models/entities/additional_fields_type.dart';
import 'package:registration_delivery/router/registration_delivery_router.gm.dart';
import 'package:registration_delivery/widgets/back_navigation_help_header.dart';
import 'package:registration_delivery/widgets/showcase/showcase_button.dart';

import 'package:registration_delivery/widgets/localized.dart';
import 'package:registration_delivery/utils/i18_key_constants.dart' as i18;
import 'package:registration_delivery/blocs/search_households/search_bloc_common_wrapper.dart';
import 'package:registration_delivery/blocs/search_households/search_households.dart';
import 'package:registration_delivery/utils/constants.dart';
import 'package:registration_delivery/utils/utils.dart';

import '../../utils/i18_key_constants.dart' as i18_local;
import '../../blocs/registration_delivery/custom_beneficairy_registration.dart';
import '../../blocs/registration_delivery/custom_search_household.dart';
import '../../router/app_router.dart';
import 'custom_beneficiary_acknowledgement.dart';

@RoutePage()
class CustomSummaryPage extends LocalizedStatefulWidget {
  final dynamic name;
  const CustomSummaryPage({
    super.key,
    super.appLocalizations,
    required this.name,
  });

  @override
  State<CustomSummaryPage> createState() => CustomSummaryPageState();
}

class CustomSummaryPageState extends LocalizedState<CustomSummaryPage> {
  final clickedStatus = ValueNotifier<bool>(false);

  String getLocalizedMessage(String code) {
    return localizations.translate(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.digitTextTheme(context);

    return PopScope(
      onPopInvoked: (val) {
        context.read<CustomBeneficiaryRegistrationBloc>().add(
              BeneficiaryRegistrationCreateEvent(
                projectId: RegistrationDeliverySingleton().projectId!,
                userUuid: RegistrationDeliverySingleton().loggedInUserUuid!,
                boundary: RegistrationDeliverySingleton().boundary!,
              ),
            );
      },
      child: Scaffold(
          body: BlocConsumer<CustomBeneficiaryRegistrationBloc,
              BeneficiaryRegistrationState>(
        listener: (context, householdState) {
          final router = context.router;
          householdState.mapOrNull(
            persisted: (value) {
              if (value.navigateToRoot) {
                (router.parent() as StackRouter).maybePop();
              } else {
                router.popUntil((route) =>
                    route.settings.name == SearchBeneficiaryRoute.name);
                context.read<SearchBlocWrapper>().searchHouseholdsBloc.add(
                      SearchHouseholdsEvent.searchByHousehold(
                        householdModel: value.householdModel,
                        projectId: RegistrationDeliverySingleton().projectId!,
                        isProximityEnabled: false,
                      ),
                    );
                router.push(CustomBeneficiaryAcknowledgementRoute(
                  enableViewHousehold: true,
                  acknowledgementType: AcknowledgementType.addHousehold,
                ));
              }
            },
          );
        },
        builder: (context, householdState) {
          // ++ ADD THIS HELPER FUNCTION ++
          // Helper function to safely extract values from additionalFields
          String getAdditionalFieldValue(String key) {
            final value = householdState
                .householdModel?.additionalFields?.fields
                .where((h) => h.key == key)
                .firstOrNull
                ?.value;
            return value?.toString() ?? '0';
          }

          return ScrollableContent(
              enableFixedDigitButton: true,
              header: Column(children: [
                const Padding(
                  padding: EdgeInsets.only(bottom: spacer2),
                  child: BackNavigationHelpHeaderWidget(
                    showHelp: false,
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: spacer2, left: spacer2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      localizations.translate(
                        i18.common.coreCommonSummaryDetails,
                      ),
                      style: textTheme.headingXl
                          .copyWith(color: theme.colorTheme.primary.primary2),
                    ),
                  ),
                ),
              ]),
              footer: DigitCard(
                  margin: const EdgeInsets.only(top: spacer2),
                  children: [
                    ValueListenableBuilder(
                      valueListenable: clickedStatus,
                      builder: (context, bool isClicked, _) {
                        return DigitButton(
                          label: householdState.mapOrNull(
                                editIndividual: (value) => localizations
                                    .translate(i18.common.coreCommonSave),
                              ) ??
                              localizations
                                  .translate(i18.common.coreCommonSubmit),
                          type: DigitButtonType.primary,
                          size: DigitButtonSize.large,
                          mainAxisSize: MainAxisSize.max,
                          isDisabled: isClicked ? true : false,
                          onPressed: () async {
                            final bloc = context
                                .read<CustomBeneficiaryRegistrationBloc>();
                            final userId = RegistrationDeliverySingleton()
                                .loggedInUserUuid;
                            final projectId =
                                RegistrationDeliverySingleton().projectId;

                            householdState.maybeWhen(
                              orElse: () {
                                return;
                              },
                              summary: (
                                navigateToRoot,
                                householdModel,
                                individualModel,
                                projectBeneficiaryModel,
                                registrationDate,
                                addressModel,
                                loading,
                                isHeadOfHousehold,
                              ) async {
                                final submit = await showDialog(
                                  context: context,
                                  builder: (ctx) => Popup(
                                    title: localizations.translate(
                                      i18.deliverIntervention.dialogTitle,
                                    ),
                                    description: localizations.translate(
                                      i18.deliverIntervention.dialogContent,
                                    ),
                                    actions: [
                                      DigitButton(
                                          label: localizations.translate(
                                            i18.common.coreCommonSubmit,
                                          ),
                                          onPressed: () {
                                            clickedStatus.value = true;
                                            Navigator.of(
                                              context,
                                              rootNavigator: true,
                                            ).pop(true);
                                          },
                                          type: DigitButtonType.primary,
                                          size: DigitButtonSize.large),
                                      DigitButton(
                                          label: localizations.translate(
                                            i18.common.coreCommonCancel,
                                          ),
                                          onPressed: () => Navigator.of(
                                                context,
                                                rootNavigator: true,
                                              ).pop(false),
                                          type: DigitButtonType.secondary,
                                          size: DigitButtonSize.large)
                                    ],
                                  ),
                                );

                                if (submit ?? false) {
                                  if (context.mounted) {
                                    final CustomSearchHouseholdsBloc
                                        customSearchHouseholdsBloc = context
                                            .read<CustomSearchHouseholdsBloc>();
                                    bloc.add(
                                      BeneficiaryRegistrationCreateEvent(
                                          projectId: projectId!,
                                          userUuid: userId!,
                                          boundary:
                                              RegistrationDeliverySingleton()
                                                  .boundary!,
                                          tag: projectBeneficiaryModel?.tag,
                                          navigateToSummary: false),
                                    );
                                    customSearchHouseholdsBloc.add(
                                        const CustomSearchHouseholdsEvent
                                            .clear());
                                    customSearchHouseholdsBloc.add(
                                      CustomSearchHouseholdsEvent
                                          .searchByHouseholdHead(
                                        searchText: widget.name.trim(),
                                        projectId: projectId!,
                                        isProximityEnabled: false,
                                        maxRadius:
                                            RegistrationDeliverySingleton()
                                                .maxRadius,
                                        limit: customSearchHouseholdsBloc
                                            .state.limit,
                                        offset: 0,
                                      ),
                                    );
                                    context.router.popUntil((route) =>
                                        route.settings.name ==
                                        SearchBeneficiaryRoute.name);
                                    context.router.push(
                                        CustomBeneficiaryAcknowledgementRoute(
                                      enableViewHousehold: true,
                                      acknowledgementType:
                                          AcknowledgementType.addHousehold,
                                    ));
                                  }
                                }
                              },
                            );
                          },
                        );
                      },
                    ),
                  ]),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      DigitCard(
                          margin: const EdgeInsets.all(spacer2),
                          children: [
                            LabelValueSummary(
                                padding: EdgeInsets.zero,
                                heading: localizations.translate(i18
                                    .householdLocation
                                    .householdLocationLabelText),
                                headingStyle: textTheme.headingL.copyWith(
                                  color: theme.colorTheme.primary.primary2,
                                ),
                                items: [
                                  LabelValueItem(
                                      label: localizations.translate(
                                          i18.householdLocation.villageLabel),
                                      value: localizations.translate(
                                          householdState.householdModel?.address
                                                  ?.locality?.code ??
                                              i18.common.coreCommonNA),
                                      isInline: true,
                                      labelFlex: 5,
                                      padding: const EdgeInsets.only(
                                          bottom: spacer2)),
                                  LabelValueItem(
                                    label: localizations.translate(i18
                                        .householdLocation.landmarkFormLabel),
                                    value: householdState.householdModel
                                            ?.address?.landmark ??
                                        localizations
                                            .translate(i18.common.coreCommonNA),
                                    isInline: true,
                                    labelFlex: 5,
                                    padding:
                                        const EdgeInsets.only(top: spacer2),
                                  ),
                                ]),
                          ]),
                      DigitCard(
                          margin: const EdgeInsets.all(spacer2),
                          children: [
                            LabelValueSummary(
                              withDivider: true,
                                padding: const EdgeInsets.fromLTRB(spacer2, 0, spacer2, 0),
                                heading: localizations.translate(
                                    i18.householdDetails.householdDetailsLabel),
                                headingStyle: textTheme.headingL.copyWith(
                                  color: theme.colorTheme.primary.primary2,
                                ),
                                items: [
                                  // LabelValueItem(
                                  //     label: localizations.translate(i18
                                  //         .householdDetails
                                  //         .noOfMembersCountLabel),
                                  //     value: householdState
                                  //             .householdModel?.memberCount
                                  //             .toString() ??
                                  //         '0',
                                  //     isInline: true,
                                  //     labelFlex: 5,
                                  //     padding: const EdgeInsets.only(
                                  //         bottom: spacer2)),
                                  // ++ ADD THESE THREE LabelValueItem WIDGETS ++
                                  LabelValueItem(
                                    label: localizations.translate(
                                      i18_local.householdDetails
                                          .numberOfChildren0To59MonthsLabel,
                                    ),
                                    value: getAdditionalFieldValue(
                                        'children0to59'),
                                    isInline: true,
                                    labelFlex: 5,
                                    padding:
                                        const EdgeInsets.only(bottom: spacer2),
                                  ),
                                  LabelValueItem(
                                    label: localizations.translate(
                                      i18_local.householdDetails
                                          .numberOfChildren0To11MonthsLabel,
                                    ),
                                    value: getAdditionalFieldValue(
                                        'children0to11'),
                                    isInline: true,
                                    labelFlex: 5,
                                    padding:
                                        const EdgeInsets.only(bottom: spacer2),
                                  ),
                                  LabelValueItem(
                                    label: localizations.translate(
                                      i18_local.householdDetails
                                          .numberOfChildren12To59MonthsLabel,
                                    ),
                                    value: getAdditionalFieldValue(
                                        'children12to59'),
                                    isInline: true,
                                    labelFlex: 5,
                                  ),

                                  /* LabelValueItem(
                                    label: localizations.translate(i18
                                        .householdDetails
                                        .noOfPregnantWomenCountLabel),
                                    value: householdState.householdModel
                                            ?.additionalFields?.fields
                                            .where((h) =>
                                                h.key ==
                                                AdditionalFieldsType
                                                    .pregnantWomen
                                                    .toValue())
                                            .firstOrNull
                                            ?.value
                                            .toString() ??
                                        '0',
                                    isInline: true,
                                    labelFlex: 5,
                                  ),
                                  LabelValueItem(
                                      label: localizations.translate(i18
                                          .householdDetails
                                          .noOfChildrenBelow5YearsLabel),
                                      value: householdState.householdModel
                                              ?.additionalFields?.fields
                                              .where((h) =>
                                                  h.key ==
                                                  AdditionalFieldsType.children
                                                      .toValue())
                                              .firstOrNull
                                              ?.value
                                              .toString() ??
                                          '0',
                                      isInline: true,
                                      labelFlex: 5,
                                      padding:
                                           const EdgeInsets.only(top: spacer2)),*/
                                ]),
                          ]),
                      // DigitCard(
                      //     margin: const EdgeInsets.all(spacer2),
                      //     children: [
                      //       LabelValueSummary(
                      //           padding: EdgeInsets.zero,
                      //           heading: localizations.translate(
                      //               i18.householdDetails.houseDetailsLabel),
                      //           headingStyle: textTheme.headingL.copyWith(
                      //             color: theme.colorTheme.primary.primary2,
                      //           ),
                      //           items: [
                      //             LabelValueItem(
                      //                 label: localizations.translate(
                      //                     i18.householdDetails.noOfRoomsLabel),
                      //                 value: householdState.householdModel
                      //                         ?.additionalFields?.fields
                      //                         .where((h) =>
                      //                             h.key ==
                      //                             AdditionalFieldsType.noOfRooms
                      //                                 .toValue())
                      //                         .firstOrNull
                      //                         ?.value
                      //                         .toString() ??
                      //                     '0',
                      //                 isInline: true,
                      //                 labelFlex: 5,
                      //                 padding: const EdgeInsets.only(
                      //                     bottom: spacer2)),
                      //             LabelValueItem(
                      //                 label: localizations.translate(
                      //                     i18.householdDetails.typeOfStructure),
                      //                 value: (householdState.householdModel
                      //                             ?.additionalFields?.fields
                      //                             .where((h) =>
                      //                                 h.key ==
                      //                                 AdditionalFieldsType
                      //                                     .houseStructureTypes
                      //                                     .toValue())
                      //                             .firstOrNull
                      //                             ?.value ??
                      //                         [])
                      //                     .toString()
                      //                     .split('|')
                      //                     .map((item) =>
                      //                         getLocalizedMessage(item))
                      //                     .toList()
                      //                     .join(', '),
                      //                 isInline: true,
                      //                 labelFlex: 5,
                      //                 padding:
                      //                     const EdgeInsets.only(top: spacer2)),
                      //           ]),
                      //     ]),
                      DigitCard(
                          margin: const EdgeInsets.all(spacer2),
                          children: [
                            LabelValueSummary(
                                padding: EdgeInsets.zero,
                                heading: localizations.translate(i18
                                    .individualDetails
                                    .individualsDetailsLabelText),
                                headingStyle: textTheme.headingL.copyWith(
                                  color: theme.colorTheme.primary.primary2,
                                ),
                                items: [
                                  LabelValueItem(
                                      label: localizations.translate(
                                          i18.individualDetails.nameLabelText),
                                      value: householdState.maybeWhen(
                                          orElse: () => localizations.translate(
                                              i18.common.coreCommonNA),
                                          summary: (
                                            navigateToRoot,
                                            householdModel,
                                            individualModel,
                                            projectBeneficiaryModel,
                                            registrationDate,
                                            addressModel,
                                            loading,
                                            isHeadOfHousehold,
                                          ) =>
                                              individualModel
                                                  ?.name?.givenName ??
                                              localizations.translate(
                                                  i18.common.coreCommonNA)),
                                      labelFlex: 5,
                                      padding: const EdgeInsets.only(
                                          bottom: spacer2)),
                                  LabelValueItem(
                                    label: localizations.translate(
                                        i18.individualDetails.dobLabelText),
                                    value: householdState.maybeWhen(
                                        orElse: () => localizations
                                            .translate(i18.common.coreCommonNA),
                                        summary: (
                                          navigateToRoot,
                                          householdModel,
                                          individualModel,
                                          projectBeneficiaryModel,
                                          registrationDate,
                                          addressModel,
                                          loading,
                                          isHeadOfHousehold,
                                        ) =>
                                            individualModel?.dateOfBirth != null
                                                ? DigitDateUtils.getFilteredDate(
                                                        DigitDateUtils.getFormattedDateToDateTime(
                                                                individualModel
                                                                        ?.dateOfBirth ??
                                                                    '')
                                                            .toString(),
                                                        dateFormat: Constants()
                                                            .dateMonthYearFormat)
                                                    .toString()
                                                : localizations.translate(
                                                    i18.common.coreCommonNA)),
                                    labelFlex: 5,
                                  ),
                                  LabelValueItem(
                                      label: localizations.translate(i18
                                          .individualDetails.genderLabelText),
                                      value: householdState.maybeWhen(
                                          orElse: () => localizations.translate(
                                              i18.common.coreCommonNA),
                                          summary: (
                                            navigateToRoot,
                                            householdModel,
                                            individualModel,
                                            projectBeneficiaryModel,
                                            registrationDate,
                                            addressModel,
                                            loading,
                                            isHeadOfHousehold,
                                          ) =>
                                              individualModel?.gender != null
                                                  ? localizations.translate(
                                                      individualModel
                                                              ?.gender?.name
                                                              .toUpperCase() ??
                                                          '')
                                                  : localizations.translate(
                                                      i18.common.coreCommonNA)),
                                      labelFlex: 5,
                                      padding:
                                          const EdgeInsets.only(top: spacer2)),
                                ]),
                          ]),
                    ],
                  ),
                )
              ]);
        },
      )),
    );
  }
}
