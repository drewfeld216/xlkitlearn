Attribute VB_Name = "mdl_utils"
Option Explicit

Public alternative_temp_folder As String

Public Sub do_nothing()
    DoEvents
End Sub

Public Sub remove_shortcuts()
    Application.OnKey "^+%0", "do_nothing"
    Application.OnKey "^+%1", "do_nothing"
    Application.OnKey "^+%2", "do_nothing"
    Application.OnKey "^+%3", "do_nothing"
    Application.OnKey "^+%4", "do_nothing"
    Application.OnKey "^+%5", "do_nothing"
    Application.OnKey "^+%6", "do_nothing"
    Application.OnKey "^+%7", "do_nothing"
    Application.OnKey "^+%8", "do_nothing"
    Application.OnKey "^+%9", "do_nothing"
End Sub

Public Sub resolve_workbook_path()
    ' In the majority of cases, ThisWorkbook.FullName will provide the path of the
    ' Excel workbook correctly. Unfortunately, when the user is using OneDrive
    ' this doesn't work. This function will attempt to find the TRUE path of the
    ' workbook, and put it in cell D1 of the code_text sheet, without the trailing
    ' slash
    '
    ' This uses tips from
    '    https://stackoverflow.com/questions/33734706/excels-fullname-property-with-onedrive
    
    #If Mac Then
        ' If we have a mac, we don't want to trigger multiple file permission questions
        ' so don't check
        ThisWorkbook.Sheets("code_text").Range("D1") = ThisWorkbook.Path
        GoTo check_for_quotes
    #End If
    
    If FileExists(ThisWorkbook.FullName) Then
        ' Everything's normal, we're good to go
        ThisWorkbook.Sheets("code_text").Range("D1") = ThisWorkbook.Path
        GoTo check_for_quotes
    End If
        
    If PROD_VERSION = True Then
        On Error GoTo cant_resolve
    End If
    
    ' According to the link above, there are three possible environment variables
    ' the user's OneDrive folder could be located in
    '      "OneDriveCommercial", "OneDriveConsumer", "OneDrive"
    '
    ' Furthermore, there are two possible formats for OneDrive URLs
    '    1. "https://companyName-my.sharepoint.com/personal/userName_domain_com/Documents" & file.FullName
    '    2. "https://d.docs.live.net/d7bbaa#######1/" & file.FullName
    ' In the first case, we can find the true path by just looking for everything after /Documents. In the
    ' second, we need to look for the fourth slash in the URL
    '
    ' The code below will try every combination of the three environment variables above, and
    ' each of the two methods of parsing the URL. The file is found in *exactly* one of those
    ' locations, then we're good to go.
    '
    ' Note that this still leaves a gap - if this file (file A) is in a location that is NOT covered by the
    ' eventualities above AND a file of the exact same name (file B) exists in one of the locations that is
    ' covered above, then this function will identify File B's location as the location of this workbook,
    ' which would be wrong
        
    Dim total_found As Integer
    total_found = 0
        
    Dim found_path As String
        
    Dim i_parsing As Integer
    Dim i_env_var As Integer
    
    For i_parsing = 1 To 2
        Dim full_path_name As String
        
        If i_parsing = 1 Then
            ' Parse using method 1 above; find /Documents and take everything after, INCLUDING the
            ' leading slash
            If InStr(1, ThisWorkbook.FullName, "/Documents") Then
                full_path_name = Mid(ThisWorkbook.FullName, InStr(1, ThisWorkbook.FullName, "/Documents") + Len("/Documents"))
            Else
                full_path_name = ""
            End If
        Else
            ' Parse using method 2; find everything after the fourth slash, including that fourth
            ' slash
            Dim i_pos As Integer
            
            ' Start at the last slash in https://
            i_pos = 8
                
            Dim slash_number As Integer
            For slash_number = 1 To 2
                i_pos = InStr(i_pos + 1, ThisWorkbook.FullName, "/")
            Next slash_number
            
            full_path_name = Mid(ThisWorkbook.FullName, i_pos)
            
            ' Replace forward slahes with backslashes
        End If
        
        full_path_name = Replace(full_path_name, "/", "\")
        
        If full_path_name <> "" Then
            Dim one_drive_path As String
            
            For i_env_var = 1 To 3
                one_drive_path = Environ(Choose(i_env_var, "OneDriveCommercial", "OneDriveConsumer", "OneDrive"))
                
                If (one_drive_path <> "") And FileExists(one_drive_path & full_path_name) Then
                    Dim this_found_path As String
                    this_found_path = ParentFolder(one_drive_path & full_path_name)
                    
                    If this_found_path <> found_path Then
                        total_found = total_found + 1
                        found_path = this_found_path
                    End If
                End If
            Next i_env_var
        End If
    Next i_parsing
        
    If total_found = 1 Then
        ThisWorkbook.Sheets("code_text").Range("D1") = found_path
        GoTo check_for_quotes
    Else
    
cant_resolve:
        On Error GoTo 0
        
        MsgBox "I'm so sorry, it looks like you're using OneDrive, and try as I may I just can't find the location of your " & _
                "OneDrive folder - it's not in any of the usual places. Please move this file to a location that isn't synced " & _
                "to OneDrive and try again", vbCritical
    
        If PROD_VERSION = True Then
            ThisWorkbook.Close
        End If
    End If
    
check_for_quotes:
    Dim full_path As String
    full_path = ThisWorkbook.Sheets("code_text").Range("D1")
    #If Mac Then
        full_path = full_path & "/"
    #Else
        full_path = full_path & "\"
    #End If
    full_path = full_path & ThisWorkbook.Name
    
    If InStr(1, full_path, "'") > 0 Then
        MsgBox "Either the file name of your Excel file or the name of one of the folders it is located in contains " & _
                "a single quote. This gives Python nightmares. Please rename your file not to include a single quote, " & _
                "and move it to a folder for which the full path does not contain a single quote." & vbCrLf & vbCrLf & _
                "The path was detected as " & full_path, vbCritical
    End If
End Sub

Public Function get_full_file_name(file_name) As String
    #If Mac Then
        get_full_file_name = ThisWorkbook.Sheets("code_text").Range("D1") & "/" & file_name
    #Else
        get_full_file_name = ThisWorkbook.Sheets("code_text").Range("D1") & "\" & file_name
    #End If
End Function

' ===============
' = Sheet Utils =
' ===============

Public Function get_range(Optional ByVal caption As String = "Select a range", _
                            Optional ByVal default_val As String = "", _
                            Optional ByVal force_contiguous As Boolean = True, _
                            Optional ByVal accept_file_name As Boolean = False) As String
                            
    ' This function will display a dialogue to allow the user to select
    ' an excel range. It takes three arguments
    '   - caption          : the caption to display in the dialogue
    '   - default_val      : the default value to display
    '   - force_contiguous : if force_contiguous is True, this function
    '                        will ensure the range is contiguous and
    '                        display an error and return a blank range
    '
    ' It will return the range selected, or a blank string if cancelled
    
    ' Remove the "File: " from the default val if needed
    If accept_file_name And (Left(default_val, 5) = "File:") Then
        default_val = Mid(default_val, 7)
    End If
    
    ' Display the dialogue
    Dim dialogue_output
    dialogue_output = Application.InputBox(caption, "Select a range", default_val, , , , , 0)
    
    ' If the dialogue is cancelled, return a blank string
    If dialogue_output = False Then
        get_range = ""
        Exit Function
    Else
        ' Get the output
        dialogue_output = Application.ConvertFormula(dialogue_output, xlR1C1, xlA1)
        
        ' Remove the leading equal sign
        dialogue_output = Mid(dialogue_output, 2)
        
        ' Excel sometimes includes the output in quotes. Remove that
        If InStr(1, dialogue_output, Chr(34)) <> 0 Then
            dialogue_output = trim_ends(dialogue_output)
        End If
        
        Dim dataset_error As String
        dataset_error = validate_dataset(dialogue_output, force_contiguous, accept_file_name)
        
        If dataset_error <> "" Then
            MsgBox dataset_error, vbExclamation
        End If
        
        get_range = dialogue_output
    End If
End Function

Public Function validate_dataset(ByRef r, Optional ByVal force_contiguous As Boolean = True, _
                                                    Optional ByVal accept_file_name As Boolean = False) As String
    ' Check whether the input is a file. Because of various complications (OneDrive, Mac sandbox, etc...),
    ' we do this in the least restrictive way possible - by checking whether the file has a .csv or .xlsx
    ' or .xls extension (those are the ones accepted by the add-in)
    If accept_file_name And (Right(r, 4) = ".csv" Or _
                                Right(r, 4) = ".xls" Or _
                                    Right(r, 5) = ".xlsx") Then
        r = "File: " & r
        validate_dataset = ""
        Exit Function
    End If
    
    ' Check whether it's contiguous by checking whether there is a comma
    ' in the range
    If force_contiguous Then
        If InStr(1, r, ",") > 0 Then
            ' MsgBox "Please select a contiguous range.", vbExclamation
            r = ""
            validate_dataset = "Please select a contiguous range."
            Exit Function
        End If
    End If
    
    ' If this cell reference doesn't contain a sheet, add it
    If InStr(1, r, "!") = 0 Then
        r = "[" & ActiveWorkbook.Name & "]" & ActiveWorkbook.ActiveSheet.Name & "!" & r
    End If
    
    ' Ensure this is a valid range
    If check_valid_range(r) = False Then
        If accept_file_name Then
            Dim accepted_files As Variant
            accepted_files = Array("xls", "xlsx", "csv")
            If InStr(Right(r, 6), ".") And IsError(Application.Match(Split(r, ".")(1), accepted_files, 0)) Then
                validate_dataset = "XLKitLearn can only accept xls, xlsx, and csv files."
            Else
                validate_dataset = "Please enter a valid range. You can also enter a file name, provided it exists in the same directory as this spreadsheet."
            End If
        Else
            validate_dataset = "Please enter a valid range."
        End If
        
        r = ""
        validate_dataset = "Please enter a valid range."
        Exit Function
    End If
    
    r = r
    validate_dataset = ""
End Function

Public Function check_valid_range(r) As Boolean
    ' This function takes a single argument r and checks
    ' whether it is a valid Excel range
    
    Dim v As Range
    On Error Resume Next
    Set v = Range(remove_workbook_from_range(r))
    If err.Number > 0 Then
        check_valid_range = False
    Else
        check_valid_range = True
    End If
    Set v = Nothing
End Function

Public Function remove_workbook_from_range(r) As String
    ' Will take a range of the form
    '    '[XLKitLearn.xlsm]NYC public schools data'!$A$1:$AB$4128
    ' and return
    '    'NYC public schools data'!$A$1:$AB$4128'
    
    If Left(r, 2) = "'[" And InStr(1, r, "]") >= 3 Then
        remove_workbook_from_range = "'" & Split(r, "]")(1)
    ElseIf Left(r, 1) = "[" And InStr(1, r, "]") >= 2 Then
        remove_workbook_from_range = Split(r, "]")(1)
    Else
        remove_workbook_from_range = r
    End If
End Function


Function get_temp_path() As String
    ' Get a temporary path that won't upest the Apple sandbox
    
    If alternative_temp_folder <> "" Then
        get_temp_path = alternative_temp_folder
    Else
        #If Mac Then
            get_temp_path = Environ("HOME") + "/"
        #Else
            get_temp_path = Environ("APPDATA") + "\"
        #End If
    End If
End Function

Function run_id(Optional create_new As Boolean = False, Optional extra_seed As Long = 0) As String
    On Error Resume Next
    
    run_id = Sheets("code_text").Range("B1").Value
    
    If create_new Then
        Randomize (DateDiff("s", #1/1/1970#, Now()) + extra_seed)
                
        run_id = "R" & Replace(Str(Round(Rnd() * 1000000, 0)) & _
                            Str(Round(Rnd() * 1000000, 0)) & _
                            Str(Round(Rnd() * 1000000, 0)), " ", "")
        
        Sheets("code_text").Range("B1").Value = run_id
    End If
End Function

Function addin_version() As String
    addin_version = Mid(ThisWorkbook.Names("version"), 2)
End Function

' ==============
' = Misc Utils =
' ==============

Public Function trim_ends(ByVal s) As String
    ' This function takes a string and removes the first and last
    ' character
    s = Trim(s)
    trim_ends = Mid(s, 2, Len(s) - 2)
End Function

Public Function GetClipBoardText() As String
    ' This function gets the content from the Windows clipboard
    
    Dim ClipBoard As MSForms.DataObject
    Set ClipBoard = New MSForms.DataObject
    ClipBoard.GetFromClipboard
    GetClipBoardText = ClipBoard.GetText
    Set ClipBoard = Nothing
End Function

Public Function check_valid_param(s As String, Optional in_progress As Boolean = False) As Boolean
    ' Function checks whether the parameter string provided is valid. If
    ' in_progress is True, it allows a trailing & sign
    
    ' Define a counter
    Dim i As Integer
    
    ' Make sure we only have digits and & signs and spaces; remove the spaces
    Dim new_s As String
    For i = 1 To Len(s)
        Dim cur_c As String: cur_c = Mid(s, i, 1)
        If (Asc(cur_c) < 48 Or Asc(cur_c) > 57) And cur_c <> "&" And cur_c <> " " Then
            check_valid_param = False
            Exit Function
        ElseIf cur_c <> " " Then
            new_s = new_s & cur_c
        End If
    Next i
    
    ' Make sure each entry contains at least one digit (except possibly
    ' for the last one if in_progress)
    Dim split_s: split_s = Split(new_s, "&")
    For i = 0 To UBound(split_s)
        If (Len(split_s(i)) = 0) And Not (in_progress And i = UBound(split_s)) Then
            check_valid_param = False
            Exit Function
        End If
    Next i
    
    check_valid_param = True
End Function

Public Function variable_valid(Item, Optional allow_substring As Boolean = False) As String
    Dim i As Integer
    Dim cur_item As String
    
    Item = Trim(Item)
    If Item = "" Then Exit Function
    
    Item = Split(Item, ",")(0)
    If Item = "" Then Exit Function
    Item = Split(Item, "<")(0)
    If Item = "" Then Exit Function
    Item = Split(Item, "=")(0)
    If Item = "" Then Exit Function
    Item = Split(Item, ">")(0)
    If Item = "" Then Exit Function
    
    Item = Trim(Item)
    
    For i = 1 To vars.count
        If allow_substring Then
            cur_item = Mid(vars.Item(i), 1, Len(Item))
        Else
            cur_item = vars.Item(i)
        End If
        
        If Item = cur_item Then
            variable_valid = vars.Item(i)
            Exit Function
        End If
    Next i
End Function

Public Function validate_formula(formula_text As String) As String
    Const INVALID_FORMULA_FORM = "Every formula needs to be in the format y ~ x. For example, y ~ x1 && y ~ x1 + x2 " & _
                                    "is correct, but y ~ x1 && x1 + x2 is incorrect."

    On Error GoTo unknown_err

    Dim i As Integer
    Dim single_formulas As Variant
    single_formulas = Split(formula_text, "&")

    For i = 0 To UBound(single_formulas)
        If InStr(1, single_formulas(i), "~") = 0 Then
            validate_formula = INVALID_FORMULA_FORM
            Exit Function
        End If
    Next i
    
    Dim formula_parts As Variant
    Dim invalid_terms As New Collection
    
    ' Keep track of the outcome column in our formulas; we want to ensure there's
    ' only one outcome variable in all our formulas
    Dim outcome_col As String
    
    For i = 0 To UBound(single_formulas)
        If Trim(single_formulas(i)) = "" Then
            validate_formula = "Please complete your formula."
            Exit Function
        End If
        
        formula_parts = Split(single_formulas(i), "~")
        
        If Trim(formula_parts(0)) = "" Then
            validate_formula = "At least one of your formulas does not have a term to the left of ~. " & _
                                           vbCrLf & "The problematic formula was " & single_formulas(i) & "."
            Exit Function
        End If
        
        If (outcome_col <> "") And (outcome_col <> Replace(formula_parts(0), " ", "")) Then
            validate_formula = "When you enter multiple formulas, the outcome variable to the left of ~ must " & _
                                    "be the same for all formulas. K-fold cross validation wouldn't really make " & _
                                    "sense otherwise."
            Exit Function
        End If
        outcome_col = Replace(formula_parts(0), " ", "")
        
        ' Remove parentheses from around the y part of the formula
        formula_parts(0) = Split(formula_parts(0), ")")(0)
        formula_parts(0) = Split(formula_parts(0), "(")(UBound(Split(formula_parts(0), "(")))
        
        Dim equals_sign As Boolean
        equals_sign = False
        If InStr(formula_parts(0), "=") > 0 Then
            equals_sign = True
            
            ' Only keep the variable names
            formula_parts(0) = Trim(Split(formula_parts(0), "=")(0))
        End If
        
        If vars.count > 0 And variable_valid(formula_parts(0)) = "" Then
            invalid_terms.Add (Trim(formula_parts(0)))
        End If
        
        ' If we've checked the numerical status of our columns, make sure the output
        ' (y) column is numeric. Also keep track of whether the rest of the columns are
        ' numeric so we can check whether a dot formula is appropriate later
        If var_types.count > 0 Then
            Dim all_numeric As Boolean
            all_numeric = True
        
            Dim w As Integer
            For w = 1 To var_types.count
                If (var_types.Item(w) <> "numeric") And (Not (vars.Item(w) = formula_parts(0) And equals_sign)) Then
                    all_numeric = False
                End If
                
                If vars.Item(w) = formula_parts(0) Then
                    If var_types.Item(w) = "missing" Then
                        validate_formula = "You are using " & formula_parts(0) & " as an output variable, but that column " & _
                                               "has missing values in some rows"
                        Exit Function
                        
                    ElseIf var_types.Item(w) = "string" And (Not equals_sign) Then
                        validate_formula = "You are using " & formula_parts(0) & " as an output variable, but that column " & _
                                               "has non-numeric values in some rows"
                        Exit Function
                    End If
                End If
            Next w
            
            ' If we have a dot formula, make sure every column is numeric
            If Replace(Replace(formula_parts(1), " ", ""), "-1", "") = "." Then
                If all_numeric = False Then
                    validate_formula = "You are using a dot-formula of the form y ~ ., but your columns are not all numeric. " & _
                                        "XLKitLearn cannot automatically generate categorical variables for you when you use dot " & _
                                        "formulas."
                    Exit Function
                End If
            End If
        End If
        
        ' Now split the second part of the formula
        formula_parts = Split(formula_parts(1) + " ", "+")
        
        Dim j As Integer
        For j = 0 To UBound(formula_parts)
            If Trim(formula_parts(j)) = "" Then
                validate_formula = "Please complete your formula. The problematic formula was " & single_formulas(i) & "."
                Exit Function
            End If
            
            Dim this_term As Variant
            this_term = Split(formula_parts(j) & " ", "(")
            this_term = Split(this_term(UBound(this_term)), ")")(0)
            this_term = Split(this_term, "*")
            
            Dim k As Integer
            For k = 0 To UBound(this_term)
                If InStr(Trim(this_term(k)), "-1") Or InStr(Trim(this_term(k)), "- 1") Then
                    this_term(k) = Trim(Split(this_term(k), "-")(0))
                End If
                
                If Trim(this_term(k)) = "" Then
                    validate_formula = "Please complete your formula. The problematic formula was " & single_formulas(i) & "."
                    Exit Function
                End If
                
                If vars.count > 0 And variable_valid(this_term(k)) = "" Then invalid_terms.Add (Trim(this_term(k)))
            Next k
        
        Next j
        
    Next i
     
    If invalid_terms.count > 0 Then
        validate_formula = "It looks like at least one term in your formula(s) does not exist in your data. " & _
                    "The problematic terms were "
        For i = 1 To invalid_terms.count
            validate_formula = validate_formula & invalid_terms.Item(i)
            If i <> invalid_terms.count Then validate_formula = validate_formula & ", "
        Next i
        validate_formula = validate_formula & ". Please remember these variable names are case sensitive."
    End If
    
    Exit Function
unknown_err:
    validate_formula = "Unknown error. Note that this might be a bug in the error-checking code rather than in your formula, so feel free to try and run it anyway and see if it works!"
End Function

Public Function localize_number(n) As Double
    On Error GoTo try_two
    
    If Int("1,00") = 1 Then
        ' Comma is decimal separator
        localize_number = Replace(n, ".", ",")
        Exit Function
    End If
    
try_two:
    
    localize_number = n
    
    On Error GoTo 0
    
End Function

Public Function pad_string(s As String, tot_length As Integer)
    If Len(s) > tot_length Then
        pad_string = Left(s, tot_length - 4) & "... "
    Else
        pad_string = s
        Dim i As Integer
        For i = Len(s) To tot_length - 1
            pad_string = pad_string & " "
        Next i
    End If
End Function

Public Function valid_var_chars(strSource As String) As Boolean
    valid_var_chars = True

    Dim i As Integer
    For i = 1 To Len(strSource)
        Select Case Asc(Mid(strSource, i, 1))
            Case 48 To 57, 65 To 90, 97 To 122, 95:
                DoEvents
            Case Else
                valid_var_chars = False
                Exit Function
        End Select
    Next i
    
End Function

Public Sub pause_execution(s As Long)
    Dim start_time As Long
    start_time = Timer
    
    While Timer - start_time < s
        DoEvents
    Wend
End Sub
