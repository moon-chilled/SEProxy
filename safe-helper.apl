)xload ws/dfns
⎕FIX 'file:///home/elronnd/aplbot/dyalog-safe-exec/Safe.dyalog'

∇R←n f r
:Trap 0
    x←n Safe.Exec r

    :If (1≡≡∧⍬≡⍴)x
        ⎕←x dft 0
    :Else
        :If ((0=≡)∧(~⍕≡⊢)) x
            ⎕←x
        :Else
            ⎕←display x
        :EndIf
    :EndIf
    R←0
:Case 6
    R←0
:Case 10
    ⎕←'(MAGIC)Execution timed out'
    R←0
:Case 11
    ⎕←'(MAGIC)Illegal code'
    R←0
:Else
    ⎕←'(MAGIC)',⍕⎕em ⎕en-200
    R←0
:EndTrap
∇

n←⎕ns ⍬
⎕pw←32767
