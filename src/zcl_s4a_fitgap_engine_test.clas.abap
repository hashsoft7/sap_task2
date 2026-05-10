CLASS zcl_s4a_fitgap_engine_test DEFINITION
  PUBLIC
  CREATE PUBLIC
  FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    DATA mo_cut TYPE REF TO zcl_s4a_fitgap_engine.

    METHODS setup.
    METHODS empty_inputs FOR TESTING.
    METHODS optional_missing_no_gap FOR TESTING.
    METHODS missing_required FOR TESTING.
    METHODS deactivated_required FOR TESTING.
    METHODS extra_custom_severity_medium FOR TESTING.
    METHODS extra_custom_severity_high FOR TESTING.
    METHODS extra_custom_score_cap_100 FOR TESTING.
    METHODS custom_code_risk_medium FOR TESTING.
    METHODS custom_code_risk_hi_cap FOR TESTING.
    METHODS combined_rules_same_scope_item FOR TESTING.
    METHODS sort_tie_break_by_scope_item FOR TESTING.
    METHODS extension_point_rule FOR TESTING.

ENDCLASS.

CLASS zcl_s4a_fitgap_engine_test IMPLEMENTATION.

  METHOD setup.
    CREATE OBJECT mo_cut.
  ENDMETHOD.

  METHOD empty_inputs.
    DATA(lt_gaps) = mo_cut->evaluate_gaps(
      it_actual   = VALUE #( )
      it_baseline = VALUE #( ) ).
    cl_abap_unit_assert=>assert_initial( lt_gaps ).
  ENDMETHOD.

  METHOD optional_missing_no_gap.
    DATA(lt_gaps) = mo_cut->evaluate_gaps(
      it_actual   = VALUE #( )
      it_baseline = VALUE #( ( scope_item = '001' is_required = abap_false max_allowed_custom_fields = 0 ) ) ).
    cl_abap_unit_assert=>assert_initial( lt_gaps ).
  ENDMETHOD.

  METHOD missing_required.
    DATA(lt_gaps) = mo_cut->evaluate_gaps(
      it_actual   = VALUE #( )
      it_baseline = VALUE #( ( scope_item = 'MISSING001' is_required = abap_true max_allowed_custom_fields = 0 ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt_gaps ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'MISSING' act = lt_gaps[ 1 ]-gap_type ).
    cl_abap_unit_assert=>assert_equals( exp = 'H' act = lt_gaps[ 1 ]-severity ).
    cl_abap_unit_assert=>assert_equals( exp = 90 act = lt_gaps[ 1 ]-score ).
  ENDMETHOD.

  METHOD deactivated_required.
    DATA(lt_gaps) = mo_cut->evaluate_gaps(
      it_actual   = VALUE #( ( scope_item = 'D1' process_name = 'P' is_active = abap_false custom_fields = 0 custom_code = 0 ) )
      it_baseline = VALUE #( ( scope_item = 'D1' is_required = abap_true max_allowed_custom_fields = 5 ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt_gaps ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'DEACTIVATED' act = lt_gaps[ 1 ]-gap_type ).
    cl_abap_unit_assert=>assert_equals( exp = 85 act = lt_gaps[ 1 ]-score ).
  ENDMETHOD.

  METHOD extra_custom_severity_medium.
    DATA(lt_gaps) = mo_cut->evaluate_gaps(
      it_actual   = VALUE #( ( scope_item = 'E1' process_name = 'P' is_active = abap_true custom_fields = 10 custom_code = 0 ) )
      it_baseline = VALUE #( ( scope_item = 'E1' is_required = abap_false max_allowed_custom_fields = 5 ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt_gaps ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'EXTRA_CUSTOM' act = lt_gaps[ 1 ]-gap_type ).
    cl_abap_unit_assert=>assert_equals( exp = 'M' act = lt_gaps[ 1 ]-severity ).
    cl_abap_unit_assert=>assert_equals( exp = 90 act = lt_gaps[ 1 ]-score ).
  ENDMETHOD.

  METHOD extra_custom_severity_high.
    DATA(lt_gaps) = mo_cut->evaluate_gaps(
      it_actual   = VALUE #( ( scope_item = 'E2' process_name = 'P' is_active = abap_true custom_fields = 11 custom_code = 0 ) )
      it_baseline = VALUE #( ( scope_item = 'E2' is_required = abap_false max_allowed_custom_fields = 5 ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'H' act = lt_gaps[ 1 ]-severity ).
  ENDMETHOD.

  METHOD extra_custom_score_cap_100.
    DATA(lt_gaps) = mo_cut->evaluate_gaps(
      it_actual   = VALUE #( ( scope_item = 'E3' process_name = 'P' is_active = abap_true custom_fields = 20 custom_code = 0 ) )
      it_baseline = VALUE #( ( scope_item = 'E3' is_required = abap_false max_allowed_custom_fields = 5 ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 100 act = lt_gaps[ 1 ]-score ).
  ENDMETHOD.

  METHOD custom_code_risk_medium.
    DATA(lt_gaps) = mo_cut->evaluate_gaps(
      it_actual   = VALUE #( ( scope_item = 'C1' process_name = 'P' is_active = abap_true custom_fields = 0 custom_code = 2 ) )
      it_baseline = VALUE #( ( scope_item = 'C1' is_required = abap_false max_allowed_custom_fields = 0 ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'M' act = lt_gaps[ 1 ]-severity ).
    cl_abap_unit_assert=>assert_equals( exp = 60 act = lt_gaps[ 1 ]-score ).
  ENDMETHOD.

  METHOD custom_code_risk_hi_cap.
    DATA(lt_gaps) = mo_cut->evaluate_gaps(
      it_actual   = VALUE #( ( scope_item = 'C2' process_name = 'P' is_active = abap_true custom_fields = 0 custom_code = 5 ) )
      it_baseline = VALUE #( ( scope_item = 'C2' is_required = abap_false max_allowed_custom_fields = 0 ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'H' act = lt_gaps[ 1 ]-severity ).
    cl_abap_unit_assert=>assert_equals( exp = 95 act = lt_gaps[ 1 ]-score ).
  ENDMETHOD.

  METHOD combined_rules_same_scope_item.
    DATA(lt_gaps) = mo_cut->evaluate_gaps(
      it_actual   = VALUE #( ( scope_item = 'X1' process_name = 'P' is_active = abap_false custom_fields = 11 custom_code = 4 ) )
      it_baseline = VALUE #( ( scope_item = 'X1' is_required = abap_true max_allowed_custom_fields = 5 ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 3 act = lines( lt_gaps ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'EXTRA_CUSTOM' act = lt_gaps[ 1 ]-gap_type ).
    cl_abap_unit_assert=>assert_equals( exp = 'CUSTOM_CODE_RISK' act = lt_gaps[ 2 ]-gap_type ).
    cl_abap_unit_assert=>assert_equals( exp = 'DEACTIVATED' act = lt_gaps[ 3 ]-gap_type ).
  ENDMETHOD.

  METHOD sort_tie_break_by_scope_item.
    DATA(lt_gaps) = mo_cut->evaluate_gaps(
      it_actual   = VALUE #( )
      it_baseline = VALUE #(
        ( scope_item = '003' is_required = abap_true max_allowed_custom_fields = 0 )
        ( scope_item = '002' is_required = abap_true max_allowed_custom_fields = 0 ) ) ).
    cl_abap_unit_assert=>assert_equals( exp = 2 act = lines( lt_gaps ) ).
    cl_abap_unit_assert=>assert_equals( exp = '002' act = lt_gaps[ 1 ]-scope_item ).
    cl_abap_unit_assert=>assert_equals( exp = '003' act = lt_gaps[ 2 ]-scope_item ).
  ENDMETHOD.

  METHOD extension_point_rule.
    DATA lo_ext TYPE REF TO ltcl_fitgap_engine_with_ext.
    CREATE OBJECT lo_ext.
    DATA(lt_gaps) = lo_ext->evaluate_gaps(
      it_actual   = VALUE #( )
      it_baseline = VALUE #( ) ).

    cl_abap_unit_assert=>assert_equals( exp = 1 act = lines( lt_gaps ) ).
    cl_abap_unit_assert=>assert_equals( exp = 'DEPRECATED_SCOPE_ITEM' act = lt_gaps[ 1 ]-gap_type ).
    cl_abap_unit_assert=>assert_equals( exp = 'L' act = lt_gaps[ 1 ]-severity ).
  ENDMETHOD.

ENDCLASS.
