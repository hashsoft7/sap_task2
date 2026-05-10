CLASS ltcl_fitgap_engine_with_ext IMPLEMENTATION.

  METHOD evaluate_additional_rules.
    append_gap(
      EXPORTING
        iv_scope_item = 'ZDEP'
        iv_gap_type   = 'DEPRECATED_SCOPE_ITEM'
        iv_severity   = 'L'
        iv_score      = 10
        iv_reason     = |Extension rule sample.|
      CHANGING ct_gaps = ct_gaps ).
  ENDMETHOD.

ENDCLASS.
