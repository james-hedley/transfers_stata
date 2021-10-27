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