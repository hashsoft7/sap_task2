CLASS zcl_s4a_fitgap_engine DEFINITION
  PUBLIC
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_actual,
        scope_item    TYPE c LENGTH 10,
        process_name  TYPE c LENGTH 80,
        is_active     TYPE abap_bool,
        custom_fields TYPE i,
        custom_code   TYPE i,
      END OF ty_actual,
      BEGIN OF ty_baseline,
        scope_item                TYPE c LENGTH 10,
        is_required                 TYPE abap_bool,
        max_allowed_custom_fields TYPE i,
      END OF ty_baseline,
      BEGIN OF ty_gap,
        scope_item TYPE c LENGTH 18,
        gap_type   TYPE c LENGTH 30,
        severity   TYPE c LENGTH 1,
        score      TYPE i,
        reason     TYPE string,
      END OF ty_gap,
      tt_actual   TYPE STANDARD TABLE OF ty_actual WITH EMPTY KEY,
      tt_baseline TYPE STANDARD TABLE OF ty_baseline WITH EMPTY KEY,
      tt_gap      TYPE STANDARD TABLE OF ty_gap WITH EMPTY KEY,
      tt_actual_h TYPE HASHED TABLE OF ty_actual WITH UNIQUE KEY scope_item.

    METHODS evaluate_gaps
      IMPORTING
        it_actual   TYPE tt_actual
        it_baseline TYPE tt_baseline
      RETURNING
        VALUE(rt_gaps) TYPE tt_gap.

  PROTECTED SECTION.

    "! Extension point (Open/Closed): override in a subclass to add rules such as DEPRECATED_SCOPE_ITEM
    "! without changing EVALUATE_GAPS or the standard rule implementations.
    METHODS evaluate_additional_rules
      IMPORTING
        it_baseline TYPE tt_baseline
        it_actual_h TYPE tt_actual_h
      CHANGING
        ct_gaps TYPE tt_gap.

    METHODS append_gap
      IMPORTING
        iv_scope_item TYPE ty_actual-scope_item
        iv_gap_type   TYPE ty_gap-gap_type
        iv_severity   TYPE ty_gap-severity
        iv_score      TYPE ty_gap-score
        iv_reason     TYPE ty_gap-reason
      CHANGING
        ct_gaps TYPE tt_gap.

  PRIVATE SECTION.

    CONSTANTS:
      gc_gap_missing          TYPE c LENGTH 30 VALUE 'MISSING',
      gc_gap_deactivated      TYPE c LENGTH 30 VALUE 'DEACTIVATED',
      gc_gap_extra_custom     TYPE c LENGTH 30 VALUE 'EXTRA_CUSTOM',
      gc_gap_custom_code_risk TYPE c LENGTH 30 VALUE 'CUSTOM_CODE_RISK',
      gc_sev_high             TYPE c LENGTH 1 VALUE 'H',
      gc_sev_medium           TYPE c LENGTH 1 VALUE 'M',
      gc_sev_low              TYPE c LENGTH 1 VALUE 'L'.

    METHODS build_actual_index
      IMPORTING
        it_actual TYPE tt_actual
      RETURNING
        VALUE(rt_h) TYPE tt_actual_h.

    METHODS evaluate_standard_rules
      IMPORTING
        it_baseline TYPE tt_baseline
        it_actual_h TYPE tt_actual_h
      CHANGING
        ct_gaps TYPE tt_gap.

    METHODS sort_gaps
      CHANGING
        ct_gaps TYPE tt_gap.

ENDCLASS.

CLASS zcl_s4a_fitgap_engine IMPLEMENTATION.

  METHOD evaluate_gaps.
    DATA(lt_actual_h) = build_actual_index( it_actual ).
    DATA(lt_gaps) = VALUE tt_gap( ).

    evaluate_standard_rules(
      EXPORTING
        it_baseline = it_baseline
        it_actual_h = lt_actual_h
      CHANGING
        ct_gaps = lt_gaps ).

    evaluate_additional_rules(
      EXPORTING
        it_baseline = it_baseline
        it_actual_h = lt_actual_h
      CHANGING
        ct_gaps = lt_gaps ).

    sort_gaps( CHANGING ct_gaps = lt_gaps ).
    rt_gaps = lt_gaps.
  ENDMETHOD.

  METHOD evaluate_additional_rules.
    " Default: no-op. Subclasses add new rules here.
  ENDMETHOD.

  METHOD build_actual_index.
    " First row wins for duplicate scope_item (deterministic).
    LOOP AT it_actual ASSIGNING FIELD-SYMBOL(<a>).
      READ TABLE rt_h TRANSPORTING NO FIELDS WITH TABLE KEY scope_item = <a>-scope_item.
      IF sy-subrc <> 0.
        INSERT <a> INTO TABLE rt_h.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD evaluate_standard_rules.
    FIELD-SYMBOLS <b> TYPE ty_baseline.
    DATA lv_overage    TYPE i.
    DATA lv_sev_extra  TYPE ty_gap-severity.
    DATA lv_score_extra TYPE i.
    DATA lv_sev_cc     TYPE ty_gap-severity.
    DATA lv_score_cc   TYPE i.

    LOOP AT it_baseline ASSIGNING <b>.
      READ TABLE it_actual_h ASSIGNING FIELD-SYMBOL(<a>) WITH TABLE KEY scope_item = <b>-scope_item.

      IF sy-subrc <> 0.
        IF <b>-is_required = abap_true.
          append_gap(
            EXPORTING
              iv_scope_item = <b>-scope_item
              iv_gap_type   = gc_gap_missing
              iv_severity   = gc_sev_high
              iv_score      = 90
              iv_reason     = |Required scope item { <b>-scope_item } is not present in actual configuration.|
            CHANGING ct_gaps = ct_gaps ).
        ENDIF.
        CONTINUE.
      ENDIF.

      IF <b>-is_required = abap_true AND <a>-is_active = abap_false.
        append_gap(
          EXPORTING
            iv_scope_item = <a>-scope_item
            iv_gap_type   = gc_gap_deactivated
            iv_severity   = gc_sev_high
            iv_score      = 85
            iv_reason     = |Scope item { <a>-scope_item } is required but inactive.|
          CHANGING ct_gaps = ct_gaps ).
      ENDIF.

      IF <a>-custom_fields > <b>-max_allowed_custom_fields.
        lv_overage = <a>-custom_fields - <b>-max_allowed_custom_fields.
        lv_sev_extra = gc_sev_medium.
        IF <a>-custom_fields > 2 * <b>-max_allowed_custom_fields.
          lv_sev_extra = gc_sev_high.
        ENDIF.
        lv_score_extra = 40 + lv_overage * 10.
        IF lv_score_extra > 100.
          lv_score_extra = 100.
        ENDIF.
        append_gap(
          EXPORTING
            iv_scope_item = <a>-scope_item
            iv_gap_type   = gc_gap_extra_custom
            iv_severity   = lv_sev_extra
            iv_score      = lv_score_extra
            iv_reason     = |Custom fields { <a>-custom_fields } exceed allowed maximum { <b>-max_allowed_custom_fields } (overage { lv_overage }).|
          CHANGING ct_gaps = ct_gaps ).
      ENDIF.

      IF <a>-custom_code > 0.
        lv_sev_cc = gc_sev_high.
        IF <a>-custom_code >= 1 AND <a>-custom_code <= 3.
          lv_sev_cc = gc_sev_medium.
        ENDIF.
        lv_score_cc = 30 + <a>-custom_code * 15.
        IF lv_score_cc > 95.
          lv_score_cc = 95.
        ENDIF.
        append_gap(
          EXPORTING
            iv_scope_item = <a>-scope_item
            iv_gap_type   = gc_gap_custom_code_risk
            iv_severity   = lv_sev_cc
            iv_score      = lv_score_cc
            iv_reason     = |Custom code count { <a>-custom_code } increases implementation risk.|
          CHANGING ct_gaps = ct_gaps ).
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

  METHOD append_gap.
    DATA(ls) = VALUE ty_gap(
      scope_item = iv_scope_item
      gap_type   = iv_gap_type
      severity   = iv_severity
      score      = iv_score
      reason     = iv_reason ).
    APPEND ls TO ct_gaps.
  ENDMETHOD.

  METHOD sort_gaps.
    TYPES:
      BEGIN OF ty_sort_line,
        sev_rank   TYPE i,
        score      TYPE i,
        scope_item TYPE c LENGTH 18,
        gap        TYPE ty_gap,
      END OF ty_sort_line.

    DATA lt_sort TYPE STANDARD TABLE OF ty_sort_line WITH EMPTY KEY.

    LOOP AT ct_gaps ASSIGNING FIELD-SYMBOL(<g>).
      DATA(lv_rank) = 2.
      CASE <g>-severity.
        WHEN gc_sev_high.
          lv_rank = 0.
        WHEN gc_sev_medium.
          lv_rank = 1.
        WHEN gc_sev_low.
          lv_rank = 2.
        WHEN OTHERS.
          lv_rank = 3.
      ENDCASE.
      APPEND VALUE #(
        sev_rank   = lv_rank
        score      = <g>-score
        scope_item = <g>-scope_item
        gap        = <g> ) TO lt_sort.
    ENDLOOP.

    SORT lt_sort BY sev_rank ASCENDING score DESCENDING scope_item ASCENDING.

    CLEAR ct_gaps.
    LOOP AT lt_sort ASSIGNING FIELD-SYMBOL(<s>).
      APPEND <s>-gap TO ct_gaps.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
