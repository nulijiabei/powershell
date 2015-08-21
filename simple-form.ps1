[Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | out-null

# create new controls 
$form = new-object system.windows.forms.form 
$button = new-object system.windows.forms.button 
$textbox = new-object system.windows.forms.textbox 
$label = new-object system.windows.forms.label 

# set up label 
$label.text = "Enter something" 
$label.top = 10 
$label.left = 10 
$label.height = 20 
$label.width = 100 

# set up text box 
$textbox.top = 30 
$textbox.left = 10 
$textbox.height = 20 
$textbox.width = 100 

# set up button 
$button.text = "OK" 
$button.width = 70 
$button.height = 25 
$button.left = 10 
$button.top = 60 

# set up button's click event 
# this script block will just hide the form, 
# allowing the main script to continue 
$button_click = { $form.hide() } 
$button.add_click($button_click) 

# set up form 
$form.text = "My dialog box" 
$form.formborderstyle = 2 
$form.height = 100 
$form.width = 120 

# add controls to form 
$form.controls.add($label) 
$form.controls.add($textbox) 
$form.controls.add($button) 

# show form 
# script will pause at this point 
$form.showdialog() | out-null 

# get user input from text box 
$userinput = $textbox.text 