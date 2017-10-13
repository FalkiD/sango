Option Explicit On 
Imports System.Math

Module Math

    ' Math variables
    Private lsfNumSamples As Long
    Private lsfSumX As Double
    Private lsfSumXSquared As Double
    Private lsfSumY As Double
    Private lsfSumXY As Double

    Public Function calcSumX(ByRef values() As Double) As Double
        Dim i As Long
        Dim size As Long
        size = UBound(values)

        For i = 0 To size
            lsfSumX = lsfSumX + values(i)
        Next
    End Function

    Public Function calcSumXSquared(ByRef values() As Double) As Double
        Dim i As Long
        Dim size As Long
        size = UBound(values)

        For i = 0 To size
            lsfSumXSquared = lsfSumXSquared + values(i) ^ 2
        Next
    End Function

    Public Function calcSumY(ByRef values() As Double) As Double
        Dim i As Long
        Dim size As Long
        size = UBound(values)

        For i = 0 To size
            lsfSumY = lsfSumY + values(i)
        Next
    End Function

    Public Function calcSumXY(ByRef valuesx() As Double, ByRef valuesy() As Double) As Double
        Dim i As Long
        Dim size As Long
        size = UBound(valuesx)

        For i = 0 To size
            lsfSumXY = lsfSumXY + valuesx(i) * valuesy(i)
        Next
    End Function

    Private Function ClearVariables()
        lsfNumSamples = 0
        lsfSumX = 0
        lsfSumXSquared = 0
        lsfSumY = 0
        lsfSumXY = 0
    End Function

    Private Function calcVariables(ByRef valuesx() As Double, ByRef valuesy() As Double)
        ClearVariables()
        Dim size As Long

        size = UBound(valuesx)
        lsfNumSamples = size + 1
        calcSumX(valuesx)
        calcSumXSquared(valuesx)
        calcSumY(valuesy)
        calcSumXY(valuesx, valuesy)
    End Function

    Public Function calcOffset(ByRef valuesx() As Double, ByRef valuesy() As Double) As Double
        calcVariables(valuesx, valuesy)
        calcOffset = (lsfSumY / lsfNumSamples) - (lsfSumX / lsfNumSamples) * _
            ((lsfNumSamples * lsfSumXY - lsfSumX * lsfSumY) / (lsfSumXSquared * lsfNumSamples - lsfSumX * lsfSumX))
    End Function

    Public Function calcGain(ByRef valuesx() As Double, ByRef valuesy() As Double) As Double
        calcVariables(valuesx, valuesy)
        calcGain = (lsfNumSamples * lsfSumXY - lsfSumX * lsfSumY) / (lsfSumXSquared * lsfNumSamples - lsfSumX * lsfSumX)
    End Function
End Module
