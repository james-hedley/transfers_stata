// Project: Stata function to create sequence variables to group episodes of care with
//          transfers into a single admission in NSW Admitted Patient Data
//          Collection (APDC)
// Adapted from: 'transfers.R' created by Timothy Dobbins, available here:
//               https://github.com/timothydobbins/hospital-transfers-multipackage
// Created by: James Hedley
// Date created: 27th October 2021
// Last updated: 27th October 2021


* Transfers program (equivalent results to R)
capture program drop transfers
program define transfers, rclass
	syntax , id(varname) admdate(varname) sepdate(varname) mode(varname) ///
		[transfer_modes(string)]
	
	quietly {
				
		** Set default transfer modes to 5 and 9
		if "`transfer_modes'" == "" local transfer_modes `""5", "9""'
		
		
		** Sort data by id, admdate, and sepdate
		sort `id' `admdate' `sepdate'


		** Generate fileseq and episode number (aka morbseq)
		gen fileseq = _n
		egen episode = seq(), by(`id')


		** Create an indicator for whether an episode is a transfer
		gen transfer = 0
		replace transfer = 1 if inlist(`mode', `transfer_modes')

		
		
		 * Create temporary variables for admission and separation dates
		 gen tempdate1 = `admdate'
		 gen tempdate2 = `sepdate'
		 
		 
		* Duplicate each observation into two observations, one for admission and one for separation
		reshape long tempdate@, i(`id' `admdate' `sepdate' episode transfer fileseq) j(date_type)
	  
	 
		* Create a variable for adjusted date, to sort observations by the order of events
		* If an admission and separation occur on the same date, the admission occurs first
		gen date_adj = tempdate + (0.1 * (date_type == 2 & transfer == 1))
	  
		* Create a numeric variable to indicate whether an observation is an admission or separation
		* This variable 'inout' will be +1 for admissions, and -1 for separations
		gen inout = 1 - (2 * (date_type == 2))
	  
	  
		* Sort the data by ID, adjusted date, episode, and date type (admissions before separations)
		gsort `id' date_adj episode -inout
		
		* Create a variable to indicate whether an observation (episode) is part of a larger admission
		* For each patient, if the cumulative sum of 'inout' drops below 1, the admission has ended
		bysort `id': gen cumsum = sum(inout)
		

		* Create a variable to indicate whether an observation (episode) is the first in the admission
		* An episode is the first in the admission if the cumulative sum of 'inout' is 1, and the
		* episode is the first for the patient or the cumulative sum of 'inout' for the previous episode
		* was 0 (i.e. the previous admission has ended)
		egen idseq = seq(), by(`id')
		bysort `id': gen newstay = 1*(cumsum==1 & (idseq==1 | (cumsum[_n-1]==0 & `id'==`id'[_n-1])))
		drop idseq
		
		
		* Create a variable to indicate which larger admission each observation (episode) belongs to
		* An observation (episode) belongs to the same admission as the previous episode if the cumulative sum
		* of 'newstay' is unchange. When 'newstay' increases, the observation is part of a new admission
		bysort `id': gen stayseq = sum(newstay)
	  

		* Remove duplicate episodes, reshape back to one row per episode (admissions and separations on the same row)
		keep if date_type == 1
		drop tempdate date_adj date_type
		
		
		* Sort data by ID and stayseq
		sort `id' episode

		* Create a variable 'transseq' to count episodes within larger admissions for each ID
		egen transseq = seq(), by(`id' stayseq)
		replace transseq = transseq - 1
		
		 * Create a variable for the first admission date of each larger admission
		egen admdate_first = min(`admdate'), by(`id' stayseq)

		* Create a variable for the final separation date of each larger admission
		egen sepdate_last = max(`sepdate'), by(`id' stayseq)
	  
	 
		* Create a variable for total length of stay
		* If separation is on same day as admission, then length of stay is 1 day
		gen totlos = sepdate_last - admdate_first
		replace totlos = 1 if totlos == 0
		
	} // end of queitly statement
	
end







* Transfers program (equivalent results to SAS)
capture program drop transfers_sas
program define transfers_sas, rclass
	syntax , id(varname) admdate(varname) sepdate(varname) mode(varname) ///
		[transfer_modes(string)]
	
	
	** Set default transfer modes to 5 and 9
	if "`transfer_modes'" == "" local transfer_modes `""5", "9""'
	
	
	** Sort data by id, admdate, and sepdate
	sort `id' `admdate' `sepdate'


	** Generate fileseq and episode number (aka morbseq)
	gen fileseq = _n
	egen episode = seq(), by(`id')


	** Create an indicator for whether an episode is a transfer
	gen transfer = 0
	replace transfer = 1 if inlist(`mode', `transfer_modes')


	** Create variables to identify nested transfers
	quietly summ episode
	global maxepisode = `r(max)'

	forvalues i = 1 / $maxepisode {
		quietly {
			
			* Display progress
			local progress = `i' / ${maxepisode}
			local progresspct = string(round(`progress'*100, 0.1)) + "%"
			noisily display "Progress: `progresspct'"
			
			
			* Set starting values for new variables (only where 'episode'==1)
			if `i' == 1 {
				gen nest_start = `admdate' if episode == 1
				gen nest_end = `sepdate' if episode == 1
				gen nest_mode = `mode' if episode == 1
				gen nested = 0 if episode == 1
				gen transseq = 0 if episode == 1
				
				format nest_start nest_end %td
			}
			
			
			* Update all variables with their previous value (equiavelent to RETAIN' in SAS)
			if `i' > 1 {
				replace nest_start = nest_start[_n-1] if episode == `i'
				replace nest_end = nest_end[_n-1] if episode == `i'
				replace nest_mode = nest_mode[_n-1] if episode == `i'
				replace nested = nested[_n-1] if episode == `i'
			
				* Update nested with it's previous value + 1 if episode is nested
				* (i.e. if admission and separation dates are before the nest end date)
				replace nested = nested + 1 if episode == `i' & (`admdate' <= nest_end & `sepdate' <= nest_end)
			
			
				* Update other nesting variables if episode is not nested
				replace nest_start = `admdate' if episode == `i' & !(`admdate' <= nest_end & `sepdate' <= nest_end)
				replace nest_mode = `mode' if episode == `i' & !(`admdate' <= nest_end & `sepdate' <= nest_end)
				replace nested = 0 if episode == `i' & !(`admdate' <= nest_end & `sepdate' <= nest_end)
				
				
				 * Update 'nest_end' if epsidoe is not nested
				 * Need to do this step separately, after updating the previous variables to ensure 'nest_end'
				 * isn't updated first, then other nesting variables updated based on the new value for 'nest_end'
				replace nest_end = `sepdate' if episode == `i' & !(`admdate' <= nest_end & `sepdate' <= nest_end)
				
				 * Update transseq if episode is:
				 * - an overlapping transfer (admission date before previous separaton date)
				 * - a nested transfer (admission date before initial record's separation date)
				 * - a transfer (mode of separation is one of those specified in 'transfer_modes'
				 * and admission date is equal to previous episode's separation date)
				replace transseq = transseq[_n-1] + 1 if episode == `i' & ///
					((nested > 0) | (`admdate' < nest_end[_n-1]) | ///
						(inlist(nest_mode[_n-1], `transfer_modes') & `admdate' == nest_end[_n-1]))
						
				replace transseq = 0 if transseq == .
		  
		  
			} // Close the if statement
		} // Close the quietly statement
	} // Close the for loop

	
	* Create a variable stayseq based on the value of transseq, within each patient
	gen stayseq = 1 if episode ==1
	replace stayseq = stayseq[_n-1] + 1*(transseq==0) if episode != 1
	
	
	 * Create a variable for the first admission date of each larger admission
	egen admdate_first = min(`admdate'), by(`id' stayseq)

	* Create a variable for the final separation date of each larger admission
	egen sepdate_last = max(`sepdate'), by(`id' stayseq)
  
 
	* Create a variable for total length of stay
	* If separation is on same day as admission, then length of stay is 1 day
	gen totlos = sepdate_last - admdate_first
	replace totlos = 1 if totlos == 0
		

end





	
