{smcl}
{cmd:help transfers_stata}
{hline}

{title:Title}

{p2col :{hi:transfers_stata} {hline 2}}For use with NSW Admitted Patient Data Collection (APDC) data.{p_end}

{phang}transfers will create new variables to group separate episodes of care together if they are part of a larger hospital admission.{p_end}
{phang}This has been adapted from 'transfers.R' created by Timothy Dobbins, available on GitHub (timothydobbins). {p_end}
{phang}transfers is an adaptation of transfers.R from Timothy Dobbins. {p_end}
{phang}transfers_sas is an adaptation of transfers.SAS, implemented in R. {p_end}
{phang}These two methods produce slightly different results, hence both functions are available depending on user preference{p_end}


{title:Syntax}

{phang}{cmd:transfers} , {opt id(varname)} {opt admdate(varname)} {opt sepdate(varname)} {opt mode(varname)} [{opt transfer_modes(string)}]

{phang}{cmd:transfers_sas} {opt id(varname)} {opt admdate(varname)} {opt sepdate(varname)} {opt mode(varname)} [{opt transfer_modes(string)}]
  

{title:Description}

{phang}{cmd:transfers} create new variables to group separate NSW APDC episodes of care together if they are part of a larger hospital admission.

{phang}{cmd:transfers_sas} Same as {cmd:transfers}, but produces slightly different results that align with results produced in SAS



{title:Options}

{phang}{opt id(varname)} is the name of the variable the identified individual patients. E.g. id("PPN")

{phang}{opt admdate(varname)} is the name of the variable containing the start date of each episode of care (i.e. the admission date). E.g. admdate("episode_start_date")

{phang}{opt sepdate(varname)} is the name of the variable containing the end date of each episode of care (i.e. the separation date). E.g. sepdate("episode_end_date")

{phang}{opt mode(varname)} is the name of the string variable containing mode of separation codes. E.g. mode("mode_of_separation_recode")

{phang}{opt transfer_modes(string)} is a single string that identifies which mode of separation codes correspond to a transfer. This will be passed to the second argument of 
	the inlist() function, and must therefore be specified using compound quotes, with each code in its own quotes, and with codes separated by a comma. 
	If not specified, then the default is to use codes "5" and "9". E.g. transfer_modes(`""5", "9""')


{title:Author}

{pstd}James Hedley{p_end}
{pstd}{browse "mailto:james.a.hedley@gmail.com":james.a.hedley@gmail.com}

{pstd}Adapted from code created by Timothy Dobbins, available here: https://github.com/timothydobbins/hospital-transfers-multipackage{p_end}
