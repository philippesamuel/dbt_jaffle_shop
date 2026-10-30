{{
    config(
        materialized='table'
    )
}}

{{- date_spine('day', "'2020-01-01'::date", "'2020-12-31'::date") -}}