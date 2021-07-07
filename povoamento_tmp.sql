use media3;

/*UPDATE media3.urgency_episodes_new SET DATE_OF_BIRTH = "2000-01-01 00:00:00"
WHERE DATE_OF_BIRTH = "";*/

UPDATE media3.urgency_procedures SET DT_CANCEL = "2000-01-01 00:00:00"
WHERE DT_CANCEL is NULL;

/*UPDATE media3.urgency_procedures SET DT_PRESCRIPTION = "2000-01-01 00:00:00"
WHERE DT_PRESCRIPTION = "";*/


#povoar dim_color
INSERT INTO dim_color
SELECT DISTINCT ID_COLOR, DESC_COLOR FROM media3.urgency_episodes_new;

#povoar dim_district
INSERT INTO dim_district (district)
SELECT DISTINCT DISTRICT FROM media3.urgency_episodes_new;

#povoar dim_diagnosis
#problema na key 52
DELETE FROM dim_diagnosis;
INSERT INTO dim_diagnosis (COD_DIAGNOSIS, DIAGNOSIS)
SELECT DISTINCT COD_DIAGNOSIS, DIAGNOSIS FROM media3.urgency_episodes_new; #where COD_DIAGNOSIS != "52";

#povoar dim_external_cause
INSERT INTO dim_external_cause
SELECT DISTINCT ID_EXT_CAUSE, DESC_EXTERNAL_CAUSE FROM media3.urgency_episodes_new;



#povoar dim_exam
INSERT INTO dim_exam (exam)
SELECT DISTINCT DESC_EXAM FROM media3.urgency_exams;

#povoar dim_drug
#Key duplicates problems nos 999999999, 67995, 194839, 19615
DELETE FROM dim_drug;
INSERT INTO dim_drug (COD_DRUG, DRUG)
SELECT DISTINCT COD_DRUG, DESC_DRUG FROM media3.urgency_prescriptions; #where COD_DRUG NOT IN (999999999,67995, 194839, 19615);

#povoar dim_intervention
INSERT INTO dim_intervention
SELECT DISTINCT ID_INTERVENTION, DESC_INTERVENTION FROM media3.urgency_procedures;

#povoar dim_reason_cancel
INSERT INTO dim_reason_cancel (reason_cancel)
SELECT DISTINCT NOTE_CANCEL FROM media3.urgency_procedures;

#povoar dim_time
INSERT INTO dim_time (date_time, date, day_of_the_week)
SELECT tab.DATE_OF_BIRTH as DATE_TIME, date(tab.DATE_OF_BIRTH) as _DATE_, dayname(tab.DATE_OF_BIRTH) as WEEK_DAY FROM
	(SELECT DISTINCT DATE_OF_BIRTH FROM media3.urgency_episodes_new
	UNION
	SELECT DISTINCT DT_ADMITION_TRAIGE FROM media3.urgency_episodes_new
	UNION
	SELECT DISTINCT DT_ADMITION_URG FROM media3.urgency_episodes_new
	UNION
	SELECT DISTINCT DT_DIAGNOSIS FROM media3.urgency_episodes_new
	UNION
	SELECT DISTINCT DT_DISCHARGE FROM media3.urgency_episodes_new
	UNION
	SELECT DISTINCT DT_PRESCRIPTION FROM media3.urgency_procedures
	UNION
	SELECT DISTINCT DT_BEGIN FROM media3.urgency_procedures
	UNION
	SELECT DISTINCT DT_CANCEL FROM media3.urgency_procedures) as tab;
    
	/*UNION SELECT DISTINCT "2000-01-01 00:00:00" FROM media3.urgency_prescriptions*/
    
    
#povoar dim_patient
DELETE FROM dim_patient;
INSERT INTO dim_patient (id_date_of_birth, id_district, sex)
SELECT DISTINCT id_time, id_district, SEX FROM media3.urgency_episodes_new as med INNER JOIN dim_district as dis ON dis.DISTRICT = med.DISTRICT
INNER JOIN dim_time AS ti ON ti.date_time = med.DATE_OF_BIRTH;

#povoar fact_exam
/*INSERT INTO fact_exam
SELECT DISTINCT id_exam, id_time, 1 FROM media3.urgency_episodes_new as med 
INNER JOIN media3.urgency_exams as ex ON ex.URG_EPISODE = med.URG_EPISODE
INNER JOIN dim_time AS ti ON ti.date_time = med.DT_ADMITION_TRAIGE
INNER JOIN dim_exam AS dexm ON dexm.exam = ex.DESC_EXAM;*/

INSERT INTO fact_exam
SELECT id_exam, id_time, count(*) FROM media3.urgency_episodes_new as med 
INNER JOIN media3.urgency_exams as ex ON ex.URG_EPISODE = med.URG_EPISODE
INNER JOIN dim_time AS ti ON ti.date_time = med.DT_ADMITION_TRAIGE
INNER JOIN dim_exam AS dexm ON dexm.exam = ex.DESC_EXAM
group by id_exam, id_time;

/*SELECT id_exam, id_time, count(id_time) FROM media3.urgency_episodes_new as med 
INNER JOIN media3.urgency_exams as ex ON ex.URG_EPISODE = med.URG_EPISODE
INNER JOIN dim_time AS ti ON ti.date_time = med.DT_ADMITION_TRAIGE
INNER JOIN dim_exam AS dexm ON dexm.exam = ex.DESC_EXAM GROUP BY id_exam limit 50000;*/


#povoar fact_procedure


-- select * from fact_procedure;

-- insert into dim_drug values(0, 0, "0");

insert into fact_procedure (id_date_prescription, id_date_canel, id_reason_cancel, id_intervention, id_drug, qtd_drug)
select dp.id_time,
dc.id_time,
rc.id_reason_cancel,
i.id_intervention,
IF(isnull(d.id_drug), 0, d.id_drug),
QT
from media3.urgency_procedures aux
join media3.urgency_prescriptions aux2 on aux.URG_EPISODE = aux2.URG_EPISODE
inner join dim_time dc on dc.date_time = aux.DT_CANCEL
inner join dim_time dp on dp.date_time = aux.DT_PRESCRIPTION
inner join dim_reason_cancel rc on rc.reason_cancel = aux.NOTE_CANCEL
inner join dim_intervention i on i.id_intervention = aux.ID_INTERVENTION
inner join dim_drug d on d.cod_drug = aux2.COD_DRUG and d.drug = aux2.DESC_DRUG;

-- povoar facto_urgency_episode
/*insert into facto_urgency_episode (id_urgency, id_date_admition, id_patient, id_external_cause, id_color,id_diagnosis, pain_scale)
select DISTINCT aux.urg_episode,
da.id_time,
p.id_patient,
ec.id_external_cause,
c.id_color,
d.id_diagnosis,
aux.pain_scale
from media3.urgency_episodes_new aux
left join dim_time da on da.date_time = aux.DT_ADMITION_URG
left join dim_patient p on p.sex = aux.SEX
left join dim_external_cause ec on ec.id_external_cause = aux.ID_EXT_CAUSE
left join dim_color c on c.id_color = aux.ID_COLOR
left join dim_diagnosis d on d.cod_diagnosis = aux.COD_DIAGNOSIS and d.diagnosis = aux.DIAGNOSIS;*/

#versão Hugo
-- DELETE FROM facto_urgency_episode;
INSERT INTO facto_urgency_episode
SELECT med.URG_EPISODE, ti.id_time, id_patient, id_external_cause, ID_COLOR, id_diagnosis,
PAIN_SCALE, TIMEDIFF(DT_ADMITION_TRAIGE, DT_ADMITION_URG), 
CASE WHEN weekday(DT_ADMITION_URG) IN (5,6) THEN 1 ELSE 0 END AS weekend, 
CASE WHEN weekday(DT_ADMITION_URG) IN (5,6) THEN 0 ELSE 1 END AS week_day FROM media3.urgency_episodes_new AS med 
INNER JOIN dim_time AS ti ON med.DT_ADMITION_URG = ti.date_time
INNER JOIN dim_district AS dis ON med.DISTRICT = dis.district
INNER JOIN dim_time AS ti1 ON med.DATE_OF_BIRTH = ti1.date_time
INNER JOIN dim_patient AS pat ON med.SEX = pat.sex AND ti1.id_time = pat.id_date_of_birth AND dis.id_district = pat.id_district
INNER JOIN dim_external_cause AS exC ON med.DESC_EXTERNAL_CAUSE = exC.external_cause
INNER JOIN dim_diagnosis AS dia ON med.DIAGNOSIS = dia.diagnosis;












select * from fact_procedures;

