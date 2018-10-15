﻿-- ------------------------------------------------------------------
-- Title: Sequential Organ Failure Assessment (SOFA)
-- This query extracts the sequential organ failure assessment (formally: sepsis-related organ failure assessment).
-- This score is a measure of organ failure for patients in the ICU.
-- The score is calculated for every hour of the patient's ICU stay.
-- However, as the calculation window is 24 hours, care should be taken when
-- using the score before the end of the first day.
-- ------------------------------------------------------------------

-- Reference for SOFA:
--    Jean-Louis Vincent, Rui Moreno, Jukka Takala, Sheila Willatts, Arnaldo De Mendonça,
--    Hajo Bruining, C. K. Reinhart, Peter M Suter, and L. G. Thijs.
--    "The SOFA (Sepsis-related Organ Failure Assessment) score to describe organ dysfunction/failure."
--    Intensive care medicine 22, no. 7 (1996): 707-710.

-- Variables used in SOFA:
--  GCS, MAP, FiO2, Ventilation status (sourced FROM `physionet-data.mimiciii_clinical.chartevents`)
--  Creatinine, Bilirubin, FiO2, PaO2, Platelets (sourced FROM `physionet-data.mimiciii_clinical.labevents`)
--  Dopamine, Dobutamine, Epinephrine, Norepinephrine (sourced FROM `physionet-data.mimiciii_clinical.inputevents_mv` and INPUTEVENTS_CV)
--  Urine output (sourced from OUTPUTEVENTS)

-- The following views required to run this query:
--  1) pivoted_bg_art - generated by pivoted-bg.sql
--  2) pivoted_uo - generated by pivoted-uo.sql
--  3) pivoted_lab - generated by pivoted-lab.sql
--  4) pivoted_gcs - generated by pivoted-gcs.sql
--  5) ventdurations - generated by ../durations/ventilation-durations.sql
--  6) norepinephrine_dose - generated by ../durations/norepinephrine-dose.sql
--  7) epinephrine_dose - generated by ../durations/epinephrine-dose.sql
--  8) dopamine_dose - generated by ../durations/dopamine-dose.sql
--  9) dobutamine_dose - generated by ../durations/dobutamine-dose.sql

-- Note:
--  The score is calculated for only adult ICU patients,
CREATE VIEW `team_l.pivoted_sofa` AS
-- generate a row for every hour the patient was in the ICU
with co_stg as
(
  select icustay_id, hadm_id
  , date_trunc('hour', intime) as intime
  , outtime
  , generate_series
  (
    -24
    , CEIL(DATETIME_DIFF(outtime, intime, HOUR))
  ) as hr
  FROM `physionet-data.mimiciii_clinical.icustays` ie
  inner join `physionet-data.mimiciii_clinical.patients` pt
    on ie.subject_id = pt.subject_id
  -- filter to adults by removing admissions with DOB ~= admission time
  where ie.intime > (DATETIME_ADD(pt.dob, INTERVAL 1 YEAR))
)
-- add in the charttime column
, co as
(
  select icustay_id, hadm_id, intime, outtime
  , DATETIME_ADD(intime, INTERVAL hr-1 HOUR) as starttime
  , DATETIME_ADD(intime, INTERVAL hr HOUR)   as endtime
  , hr
  from co_stg
)
-- get minimum blood pressure FROM `physionet-data.mimiciii_clinical.chartevents`
, bp as
(
  select ce.icustay_id
    , ce.charttime
    , min(valuenum) as MeanBP_min
  FROM `physionet-data.mimiciii_clinical.chartevents` ce
  -- exclude rows marked as error
  where (ce.error IS NULL OR ce.error = 1)
  and ce.itemid in
  (
  -- MEAN ARTERIAL PRESSURE
  456, --"NBP Mean"
  52, --"Arterial BP Mean"
  6702, --	Arterial BP Mean #2
  443, --	Manual BP Mean(calc)
  220052, --"Arterial Blood Pressure mean"
  220181, --"Non Invasive Blood Pressure mean"
  225312  --"ART BP mean"
  )
  and valuenum > 0 and valuenum < 300
  group by ce.icustay_id, ce.charttime
)
, pafi as
(
  -- join blood gas to ventilation durations to determine if patient was vent
  select ie.icustay_id
  , bg.charttime
  -- because pafi has an interaction between vent/PaO2:FiO2, we need two columns for the score
  -- it can happen that the lowest unventilated PaO2/FiO2 is 68, but the lowest ventilated PaO2/FiO2 is 120
  -- in this case, the SOFA score is 3, *not* 4.
  , case when vd.icustay_id is null then pao2fio2ratio else null end PaO2FiO2Ratio_novent
  , case when vd.icustay_id is not null then pao2fio2ratio else null end PaO2FiO2Ratio_vent
  FROM `physionet-data.mimiciii_clinical.icustays` ie
  inner join `team_l.pivoted_bg_art` bg
    on ie.icustay_id = bg.icustay_id
  left join `physionet-data.mimiciii_derived.ventdurations` vd
    on ie.icustay_id = vd.icustay_id
    and bg.charttime >= vd.starttime
    and bg.charttime <= vd.endtime
)
, mini_agg as
(
  select co.icustay_id, co.hr
  -- vitals
  , min(bp.MeanBP_min) as MeanBP_min
  -- gcs
  , min(gcs.GCS) as GCS_min
  -- uo
  , sum(uo.urineoutput) as UrineOutput
  -- labs
  , max(labs.bilirubin) as bilirubin_max
  , max(labs.creatinine) as creatinine_max
  , min(labs.platelet) as platelet_min
  from co
  left join bp
    on co.icustay_id = bp.icustay_id
    and co.starttime < bp.charttime
    and co.endtime >= bp.charttime
  left join `physionet-data.mimiciii_derived.pivoted_gcs` gcs
    on co.icustay_id = gcs.icustay_id
    and co.starttime < gcs.charttime
    and co.endtime >= gcs.charttime
  left join `team_l.pivoted_uo` uo
    on co.icustay_id = uo.icustay_id
    and co.starttime < uo.charttime
    and co.endtime >= uo.charttime
  left join `team_l.pivoted_lab` labs
    on co.hadm_id = labs.hadm_id
    and co.starttime < labs.charttime
    and co.endtime >= labs.charttime
  group by co.icustay_id, co.hr
)
, scorecomp as
(
  select
      co.icustay_id
    , co.hr
    , co.starttime, co.endtime
    , pafi.PaO2FiO2Ratio_novent
    , pafi.PaO2FiO2Ratio_vent
    , epi.vaso_rate as rate_epinephrine
    , nor.vaso_rate as rate_norepinephrine
    , dop.vaso_rate as rate_dopamine
    , dob.vaso_rate as rate_dobutamine
    , ma.MeanBP_min
    , ma.GCS_min
    -- uo
    , ma.urineoutput
    -- labs
    , ma.bilirubin_max
    , ma.creatinine_max
    , ma.platelet_min
  from co
  left join mini_agg ma
    on co.icustay_id = ma.icustay_id
    and co.hr = ma.hr
  left join pafi
    on co.icustay_id = pafi.icustay_id
    and co.starttime < pafi.charttime
    and co.endtime  >= pafi.charttime
  left join `physionet-data.mimiciii_derived.epinephrine_dose` epi
    on co.icustay_id = epi.icustay_id
    and co.endtime > epi.starttime
    and co.endtime <= epi.endtime
  left join `physionet-data.mimiciii_derived.norepinephrine_dose` nor
    on co.icustay_id = nor.icustay_id
    and co.endtime > nor.starttime
    and co.endtime <= nor.endtime
  left join `physionet-data.mimiciii_derived.dopamine_dose` dop
    on co.icustay_id = dop.icustay_id
    and co.endtime > dop.starttime
    and co.endtime <= dop.endtime
  left join `physionet-data.mimiciii_derived.dobutamine_dose` dob
    on co.icustay_id = dob.icustay_id
    and co.endtime > dob.starttime
    and co.endtime <= dob.endtime
)
, scorecalc as
(
  -- Calculate the final score
  -- note that if the underlying data is missing, the component is null
  -- eventually these are treated as 0 (normal), but knowing when data is missing is useful for debugging
  select scorecomp.*
  -- Respiration
  , cast(case
      when PaO2FiO2Ratio_vent   < 100 then 4
      when PaO2FiO2Ratio_vent   < 200 then 3
      when PaO2FiO2Ratio_novent < 300 then 2
      when PaO2FiO2Ratio_novent < 400 then 1
      when coalesce(PaO2FiO2Ratio_vent, PaO2FiO2Ratio_novent) is null then null
      else 0
    end as SMALLINT) as respiration

  -- Coagulation
  , cast(case
      when platelet_min < 20  then 4
      when platelet_min < 50  then 3
      when platelet_min < 100 then 2
      when platelet_min < 150 then 1
      when platelet_min is null then null
      else 0
    end as SMALLINT) as coagulation

  -- Liver
  , cast(case
      -- Bilirubin checks in mg/dL
        when Bilirubin_Max >= 12.0 then 4
        when Bilirubin_Max >= 6.0  then 3
        when Bilirubin_Max >= 2.0  then 2
        when Bilirubin_Max >= 1.2  then 1
        when Bilirubin_Max is null then null
        else 0
      end as SMALLINT) as liver

  -- Cardiovascular
  , cast(case
      when rate_dopamine > 15 or rate_epinephrine >  0.1 or rate_norepinephrine >  0.1 then 4
      when rate_dopamine >  5 or rate_epinephrine <= 0.1 or rate_norepinephrine <= 0.1 then 3
      when rate_dopamine >  0 or rate_dobutamine > 0 then 2
      when MeanBP_Min < 70 then 1
      when coalesce(MeanBP_Min, rate_dopamine, rate_dobutamine, rate_epinephrine, rate_norepinephrine) is null then null
      else 0
    end as SMALLINT) as cardiovascular

  -- Neurological failure (GCS)
  , cast(case
      when (GCS_min >= 13 and GCS_min <= 14) then 1
      when (GCS_min >= 10 and GCS_min <= 12) then 2
      when (GCS_min >=  6 and GCS_min <=  9) then 3
      when  GCS_min <   6 then 4
      when  GCS_min is null then null
  else 0 end as SMALLINT)
    as cns

  -- Renal failure - high creatinine or low urine output
  , case
    when (Creatinine_Max >= 5.0) then 4
    when
      SUM(urineoutput) OVER (PARTITION BY icustay_id ORDER BY hr
      ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING) < 200
        then 4
    when (Creatinine_Max >= 3.5 and Creatinine_Max < 5.0) then 3
    when
      SUM(urineoutput) OVER (PARTITION BY icustay_id ORDER BY hr
      ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING) < 500
        then 3
    when (Creatinine_Max >= 2.0 and Creatinine_Max < 3.5) then 2
    when (Creatinine_Max >= 1.2 and Creatinine_Max < 2.0) then 1
    when coalesce
      (
        SUM(urineoutput) OVER (PARTITION BY icustay_id ORDER BY hr
        ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING)
        , Creatinine_Max
      ) is null then null
  else 0 end::SMALLINT
    as renal
  from scorecomp
)
, score_final as
(
  select s.*
    -- Combine all the scores to get SOFA
    -- Impute 0 if the score is missing
   -- the window function takes the max over the last 24 hours
    , coalesce(
        MAX(respiration) OVER (PARTITION BY icustay_id ORDER BY HR
        ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING)
      ,0)::SMALLINT as respiration_24hours
     , coalesce(
         MAX(coagulation) OVER (PARTITION BY icustay_id ORDER BY HR
         ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING)
        ,0)::SMALLINT as coagulation_24hours
    , coalesce(
        MAX(liver) OVER (PARTITION BY icustay_id ORDER BY HR
        ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING)
      ,0)::SMALLINT as liver_24hours
    , coalesce(
        MAX(cardiovascular) OVER (PARTITION BY icustay_id ORDER BY HR
        ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING)
      ,0)::SMALLINT as cardiovascular_24hours
    , coalesce(
        MAX(cns) OVER (PARTITION BY icustay_id ORDER BY HR
        ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING)
      ,0)::SMALLINT as cns_24hours
    , coalesce(
        MAX(renal) OVER (PARTITION BY icustay_id ORDER BY HR
        ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING)
      ,0)::SMALLINT as renal_24hours

    -- sum together data for final SOFA
    , coalesce(
        MAX(respiration) OVER (PARTITION BY icustay_id ORDER BY HR
        ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING)
      ,0)
     + coalesce(
         MAX(coagulation) OVER (PARTITION BY icustay_id ORDER BY HR
         ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING)
      ,0)
     + coalesce(
        MAX(liver) OVER (PARTITION BY icustay_id ORDER BY HR
        ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING)
      ,0)
     + coalesce(
        MAX(cardiovascular) OVER (PARTITION BY icustay_id ORDER BY HR
        ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING)
      ,0)
     + coalesce(
        MAX(cns) OVER (PARTITION BY icustay_id ORDER BY HR
        ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING)
      ,0)
     + coalesce(
        MAX(renal) OVER (PARTITION BY icustay_id ORDER BY HR
        ROWS BETWEEN 24 PRECEDING AND 0 FOLLOWING)
      ,0)::SMALLINT
    as SOFA_24hours
  from scorecalc s
)
select * from score_final
where hr >= 0
order by icustay_id, hr;
