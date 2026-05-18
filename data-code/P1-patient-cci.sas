/* ------------------------------------------------------------ 	*/
/* TITLE:		Patient Charlson Comorbidity Index				*/
/* 			for the ortho inpatient analytic sample			*/
/* AUTHOR:		Ian McCarthy									*/
/*				Emory University								*/
/* DATE CREATED:	5/18/2026										*/
/* CODE FILE ORDER: P1 (revision-round patient-side build)		*/
/* OUTPUT:		PL027710.PatientCCI_<year> by year,			*/
/* 			PL027710.PatientCCI_All stacked.				*/
/* NOTES:		Computes Charlson Comorbidity Index per index 	*/
/* 			admission using diagnoses ICD_DGNS_CD1-25 on the */
/*			RIF inpatient claim. Uses Quan et al. (2005) 	*/
/*			ICD-9 + ICD-10 coding. ICD-9 vs ICD-10 split is	*/
/*			by claim date (Oct 1, 2015 transition): 2008-14	*/
/*			pure ICD-9, 2016-18 pure ICD-10, 2015 split via */
/*			CLM_FROM_DT. Applies standard Charlson hier-	*/
/*			archies (DM w/ comp supersedes DM, severe liver */
/*			supersedes mild liver, metastatic tumor super-	*/
/*			sedes any malignancy).							*/
/*			Single-claim CCI, not a lookback CCI — the		*/
/*			standard form for risk-adjusting index-event	*/
/*			outcomes in CMS quality measures.				*/
/* ------------------------------------------------------------ 	*/


/* ---------- ICD-9 condition macro ---------- */
%macro score_icd9;
	if dx{i} in: ('410','412') then cci_mi=1;
	if dx{i} in: ('39891','40201','40211','40291','40401','40403','40411','40413','40491','40493',
		'4254','4255','4256','4257','4258','4259','428') then cci_chf=1;
	if dx{i} in: ('0930','4373','440','441','4431','4432','4433','4434','4435','4436','4437','4438','4439',
		'4471','5571','5579','V434') then cci_pvd=1;
	if dx{i} in: ('36234','430','431','432','433','434','435','436','437','438') then cci_cvd=1;
	if dx{i} in: ('290','2941','3312') then cci_dem=1;
	if dx{i} in: ('4168','4169','490','491','492','493','494','495','496','497','498','499','500','501',
		'502','503','504','505','5064','5081','5088') then cci_cpd=1;
	if dx{i} in: ('4465','7100','7101','7102','7103','7104','7140','7141','7142','7148','725') then cci_rheum=1;
	if dx{i} in: ('531','532','533','534') then cci_ulcer=1;
	if dx{i} in: ('07022','07023','07032','07033','07044','07054','0706','0709','570','571','5733','5734',
		'5738','5739','V427') then cci_mldld=1;
	if dx{i} in: ('2500','2501','2502','2503','2508','2509') then cci_dm=1;
	if dx{i} in: ('2504','2505','2506','2507') then cci_dmcc=1;
	if dx{i} in: ('3341','342','343','3440','3441','3442','3443','3444','3445','3446','3449') then cci_hemi=1;
	if dx{i} in: ('40301','40311','40391','40402','40403','40412','40413','40492','40493','582','5830',
		'5831','5832','5833','5834','5835','5836','5837','585','586','588','V420','V451','V56') then cci_renal=1;
	if dx{i} in: ('14','15','16','170','171','172','174','175','176','177','178','179','18','190','191',
		'192','193','194','195','200','201','202','203','204','205','206','207','208','2386') then cci_malig=1;
	if dx{i} in: ('4560','4561','4562','5722','5723','5724','5725','5726','5727','5728') then cci_sevld=1;
	if dx{i} in: ('196','197','198','199') then cci_meta=1;
	if dx{i} in: ('042','043','044') then cci_hiv=1;
%mend score_icd9;


/* ---------- ICD-10 condition macro ---------- */
%macro score_icd10;
	if dx{i} in: ('I21','I22','I252') then cci_mi=1;
	if dx{i} in: ('I099','I110','I130','I132','I255','I420','I425','I426','I427','I428','I429',
		'I43','I50','P290') then cci_chf=1;
	if dx{i} in: ('I70','I71','I731','I738','I739','I771','I790','I792','K551','K558','K559',
		'Z958','Z959') then cci_pvd=1;
	if dx{i} in: ('G45','G46','H340','I60','I61','I62','I63','I64','I65','I66','I67','I68','I69') then cci_cvd=1;
	if dx{i} in: ('F00','F01','F02','F03','F051','G30','G311') then cci_dem=1;
	if dx{i} in: ('I278','I279','J40','J41','J42','J43','J44','J45','J46','J47','J60','J61','J62',
		'J63','J64','J65','J66','J67','J684','J701','J703') then cci_cpd=1;
	if dx{i} in: ('M05','M06','M315','M32','M33','M34','M351','M353','M360') then cci_rheum=1;
	if dx{i} in: ('K25','K26','K27','K28') then cci_ulcer=1;
	if dx{i} in: ('B18','K700','K701','K702','K703','K709','K713','K714','K715','K717','K73','K74',
		'K760','K762','K763','K764','K768','K769','Z944') then cci_mldld=1;
	if dx{i} in: ('E100','E101','E106','E108','E109','E110','E111','E116','E118','E119',
		'E120','E121','E126','E128','E129','E130','E131','E136','E138','E139',
		'E140','E141','E146','E148','E149') then cci_dm=1;
	if dx{i} in: ('E102','E103','E104','E105','E107','E112','E113','E114','E115','E117',
		'E122','E123','E124','E125','E127','E132','E133','E134','E135','E137',
		'E142','E143','E144','E145','E147') then cci_dmcc=1;
	if dx{i} in: ('G041','G114','G801','G802','G81','G82','G830','G831','G832','G833','G834','G839') then cci_hemi=1;
	if dx{i} in: ('I120','I131','N032','N033','N034','N035','N036','N037','N052','N053','N054',
		'N055','N056','N057','N18','N19','N250','Z490','Z491','Z492','Z940','Z992') then cci_renal=1;
	if dx{i} in: ('C0','C1','C2','C30','C31','C32','C33','C34','C37','C38','C39','C40','C41',
		'C43','C45','C46','C47','C48','C49','C50','C51','C52','C53','C54','C55',
		'C56','C57','C58','C6','C70','C71','C72','C73','C74','C75','C76','C81',
		'C82','C83','C84','C85','C88','C90','C91','C92','C93','C94','C95','C96','C97') then cci_malig=1;
	if dx{i} in: ('I850','I859','I864','I982','K704','K711','K721','K729','K765','K766','K767') then cci_sevld=1;
	if dx{i} in: ('C77','C78','C79','C80') then cci_meta=1;
	if dx{i} in: ('B20','B21','B22','B24') then cci_hiv=1;
%mend score_icd10;


/* ---------- Compute Charlson per claim ---------- */
%macro build_cci;
	%do year_data = 2008 %to 2018;

	/* Re-pull all 25 dx codes from RIF, restricted to analytic-sample
	   claims via BENE_ID + CLM_ID join back to PL027710.MajorJoint_<yr>. */
	PROC SQL;
		CREATE TABLE WORK.dx_full_&year_data AS
		SELECT b.BENE_ID, b.CLM_ID, b.CLM_FROM_DT,
			a.ICD_DGNS_CD1, a.ICD_DGNS_CD2, a.ICD_DGNS_CD3, a.ICD_DGNS_CD4, a.ICD_DGNS_CD5,
			a.ICD_DGNS_CD6, a.ICD_DGNS_CD7, a.ICD_DGNS_CD8, a.ICD_DGNS_CD9, a.ICD_DGNS_CD10,
			a.ICD_DGNS_CD11, a.ICD_DGNS_CD12, a.ICD_DGNS_CD13, a.ICD_DGNS_CD14, a.ICD_DGNS_CD15,
			a.ICD_DGNS_CD16, a.ICD_DGNS_CD17, a.ICD_DGNS_CD18, a.ICD_DGNS_CD19, a.ICD_DGNS_CD20,
			a.ICD_DGNS_CD21, a.ICD_DGNS_CD22, a.ICD_DGNS_CD23, a.ICD_DGNS_CD24, a.ICD_DGNS_CD25
		FROM
			(SELECT * FROM RIF&year_data..INPATIENT_CLAIMS_01
			 UNION ALL SELECT * FROM RIF&year_data..INPATIENT_CLAIMS_02
			 UNION ALL SELECT * FROM RIF&year_data..INPATIENT_CLAIMS_03
			 UNION ALL SELECT * FROM RIF&year_data..INPATIENT_CLAIMS_04
			 UNION ALL SELECT * FROM RIF&year_data..INPATIENT_CLAIMS_05
			 UNION ALL SELECT * FROM RIF&year_data..INPATIENT_CLAIMS_06
			 UNION ALL SELECT * FROM RIF&year_data..INPATIENT_CLAIMS_07
			 UNION ALL SELECT * FROM RIF&year_data..INPATIENT_CLAIMS_08
			 UNION ALL SELECT * FROM RIF&year_data..INPATIENT_CLAIMS_09
			 UNION ALL SELECT * FROM RIF&year_data..INPATIENT_CLAIMS_10
			 UNION ALL SELECT * FROM RIF&year_data..INPATIENT_CLAIMS_11
			 UNION ALL SELECT * FROM RIF&year_data..INPATIENT_CLAIMS_12) AS a
		INNER JOIN PL027710.MajorJoint_&year_data AS b
			ON a.BENE_ID = b.BENE_ID AND a.CLM_ID = b.CLM_ID;
	QUIT;

	/* Score Charlson conditions. ICD-9 vs ICD-10 by claim date:
	   2008-2014 ICD-9; 2016-2018 ICD-10; 2015 split at Oct 1. */
	DATA PL027710.PatientCCI_&year_data;
		SET WORK.dx_full_&year_data;
		LENGTH cci_mi cci_chf cci_pvd cci_cvd cci_dem cci_cpd cci_rheum
			cci_ulcer cci_mldld cci_dm cci_dmcc cci_hemi cci_renal
			cci_malig cci_sevld cci_meta cci_hiv 3;
		ARRAY dx{25} ICD_DGNS_CD1-ICD_DGNS_CD25;

		cci_mi=0; cci_chf=0; cci_pvd=0; cci_cvd=0; cci_dem=0; cci_cpd=0;
		cci_rheum=0; cci_ulcer=0; cci_mldld=0; cci_dm=0; cci_dmcc=0;
		cci_hemi=0; cci_renal=0; cci_malig=0; cci_sevld=0; cci_meta=0; cci_hiv=0;

		/* claim-level ICD version: 9 if before 2015-10-01, else 10 */
		if CLM_FROM_DT < '01OCT2015'd then icd_vsn=9; else icd_vsn=10;

		do i = 1 to 25;
			if missing(dx{i}) then continue;
			if icd_vsn=9 then do;
				%score_icd9;
			end;
			else do;
				%score_icd10;
			end;
		end;

		/* Hierarchies: more severe form supersedes milder form */
		if cci_dmcc=1 then cci_dm=0;
		if cci_sevld=1 then cci_mldld=0;
		if cci_meta=1 then cci_malig=0;

		/* Weighted Charlson score (Charlson 1987 weights) */
		cci_score = cci_mi + cci_chf + cci_pvd + cci_cvd + cci_dem + cci_cpd
			+ cci_rheum + cci_ulcer + cci_mldld + cci_dm
			+ 2*(cci_dmcc + cci_hemi + cci_renal + cci_malig)
			+ 3*cci_sevld
			+ 6*(cci_meta + cci_hiv);

		KEEP BENE_ID CLM_ID cci_mi cci_chf cci_pvd cci_cvd cci_dem cci_cpd
			cci_rheum cci_ulcer cci_mldld cci_dm cci_dmcc cci_hemi cci_renal
			cci_malig cci_sevld cci_meta cci_hiv cci_score;
	RUN;

	%END;
%mend build_cci;

%build_cci;


/* Stack all years */
DATA PL027710.PatientCCI_All;
	SET PL027710.PatientCCI_2008 PL027710.PatientCCI_2009 PL027710.PatientCCI_2010
		PL027710.PatientCCI_2011 PL027710.PatientCCI_2012 PL027710.PatientCCI_2013
		PL027710.PatientCCI_2014 PL027710.PatientCCI_2015 PL027710.PatientCCI_2016
		PL027710.PatientCCI_2017 PL027710.PatientCCI_2018;
RUN;
