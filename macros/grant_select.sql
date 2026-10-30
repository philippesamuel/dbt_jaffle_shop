{%- 
    macro grant_select(
        schema=target.schema, 
        role=target.role, 
        database=target.database,
        verbose=False
        ) 
-%}
    {% set sql %}
        use database {{ database }};
        grant usage on schema {{ schema }} to role {{ role }};
        grant select on all tables in schema {{ schema }} to role {{ role }};
        grant select on all views in schema {{ schema }} to role {{ role }};
    {% endset %}
    {{ log("Granting SELECT on schema {} to role {} ...".format(schema.upper(), role.upper()), info=True) }}
    {% if verbose%}
       {{ log(sql, info=True) }}
    {% endif %}
    {% do run_query(sql) %}

    {{ log("... SELECT granted on schema {} to role {}".format(schema.upper(), role.upper()), info=True) }}
{% endmacro %}
