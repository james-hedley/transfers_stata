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