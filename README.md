# transfers_stata
Stata commands to create sequence variables to group episodes of care with transfers into a single admission in NSW Admitted Patient Data Collection (APDC)

There are three ways to install this package:
  1. Install within Stata using -net install
  
    net install transfers_stata, from("https://raw.githubusercontent.com/james-hedley/transfers_stata/main/")
  
  2. Download the .ado and .sthlp files, and save them in your personal ADO folder. You can find where your personal ADO folder is located by typing -sysdir- in Stata
 
  3. Manually install within Stata (if -net install- fails). To install the command and then view the help file type:
    
    do "https://raw.githubusercontent.com/james-hedley/version_control/main/transfers_stata.do"
    
    type "https://raw.githubusercontent.com/james-hedley/version_control/main/transfers_stata.sthlp"
