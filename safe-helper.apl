
∇R←n f r
:Trap 0
    x←n Safe.Exec r
    :If 0∊⍴x
        :If ∧/∊0=⍬⍴x
            x←(⍕⍴x), ' ⍴ 0'
        :Else
            x←(⍕⍴x), ' ⍴ '' '''
        :EndIf
    :EndIf

    :If ∧/∊' '=x
        x←(⍕⍴x), ' ⍴ '' '''
    :EndIf

    R←⍕x
:Case 6
    R←''
:Case 10
    R←'(MAGIC)Execution timed out'
:Case 11
    R←'(MAGIC)Illegal code'
:Else
    R←'(MAGIC)',⍕⎕em ⎕en-200
:EndTrap
∇

n←⎕ns ⍬
