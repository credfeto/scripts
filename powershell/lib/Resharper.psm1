function Resharper_ConvertSuppressionCommentToSuppressMessage {  
param (
    [string] $sourceFolder
    )
    
    Write-Information "* Changing Resharper disable once comments to SuppressMessage"
    Write-Information "  - Folder: $sourceFolder"

    $emptyLine = [char]13 + [char]10

    $linesToRemoveRegex = "(?<LinesToRemove>((\r\n){2,}))"
    $suppressMessageRegex = "(?<End>\s+\[(System\.Diagnostics\.CodeAnalysis\.)?SuppressMessage)"
    $removeBlankLinesRegex = "(?ms)" +  "(?<Start>(^((\s+)///\s+</(.*?)\>)))" + $linesToRemoveRegex + $suppressMessageRegex
    $removeBlankLines2Regex = "(?ms)" + "(?<Start>(^((\s+)///\s+<(.*?)/\>)))" + $linesToRemoveRegex + $suppressMessageRegex

    $replacements = @(
        "AccessToModifiedClosure",
        "AccessToStaticMemberViaDerivedType",
        "AutoPropertyCanBeMadeGetOnly.Global",
        "AutoPropertyCanBeMadeGetOnly.Local",
        "ClassCanBeSealed.Global",
        "ClassCanBeSealed.Local",
        "ClassNeverInstantiated.Global",
        "ClassNeverInstantiated.Local",
        "CompareNonConstrainedGenericWithNull",
        "ConstantConditionalAccessQualifier",
        "ConvertToAutoProperty",
        "ConvertToUsingDeclaration",
        "EntityNameCapturedOnly.Local",
        "ExpressionIsAlwaysNull",
        "IdentifierTypo",
        "ImpureMethodCallOnReadonlyValueField",
        "InconsistentlySynchronizedField",
        "InconsistentNaming",
        "MemberCanBePrivate.Global",
        "MemberCanBePrivate.Local",
        "NotAccessedField.Local",
        "ParameterOnlyUsedForPreconditionCheck.Global",
        "ParameterOnlyUsedForPreconditionCheck.Local",
        "PrivateFieldCanBeConvertedToLocalVariable",
        "RedundantDefaultMemberInitializer",
        "UnusedAutoPropertyAccessor.Global",
        "UnusedAutoPropertyAccessor.Local",
        "UnusedMember.Global",
        "UnusedMember.Local",
        "UnusedParameter.Global",
        "UnusedParameter.Local",
        "UnusedType.Global",
        "UnusedType.Local",
        "UnusedTypeParameter"
    )

    $deletions = @(
        "AssignNullToNotNullAttribute",
        "ConditionIsAlwaysTrueOrFalse",
        "ConstantNullCoalescingCondition",
        "ConvertToUsingDeclaration",
        "EqualExpressionComparison",
        "ExpressionIsAlwaysNull",
        "GCSuppressFinalizeForTypeWithoutDestructor",
        "HeapView.BoxingAllocation",
        "NotAccessedField.Local",
        "PossibleNullReferenceException",
        "PropertyCanBeMadeInitOnly.Global",
        "StringLiteralTypo",
        "UnusedMethodReturnValue.Global",
        "UnusedMethodReturnValue.Local",
        "UseIndexFromEndExpression",
        "VirtualMemberCallInConstructor"
    )

    $changed = $false
    $files = Get-ChildItem -Path $sourceFolder -Filter "*.cs" -Recurse
    ForEach($file in $files) {
        $fileName = $file.FullName

        $content = Get-Content -Path $fileName -Raw
        $originalContent = $content
        $updatedContent = $content

        $changedFile = $False

        ForEach($replacement in $replacements) {
            if($replacement -eq $null) {
                continue
            }
            
            $code = $replacement.Replace(".", "\.")
            $regex = "//\s+ReSharper\s+disable\s+once\s+$code"
            $replacementText = "[System.Diagnostics.CodeAnalysis.SuppressMessage(""ReSharper"", ""$replacement"", Justification=""TODO: Review"")]"

            $updatedContent = $content -replace $regex, $replacementText
            if($content -ne $updatedContent)
            {
                $content = $updatedContent
                if($changedFile -eq $False) {
                    Write-Information "* $fileName"
                    $changedFile = $True
                }

                Write-Information "   - Changed $replacement comment to SuppressMessage"
            }
        }

        ForEach($replacement in $deletions) {
            if($replacement -eq $null) {
                continue
            }

            $code = $replacement.Replace(".", "\.")
            $regex = "//\s+ReSharper\s+disable\s+once\s+$code"
            $replacementText = ""

            $updatedContent = $content -replace $regex, $replacementText
            if($content -ne $updatedContent)
            {
                $content = $updatedContent
                if($changedFile -eq $False) {
                    Write-Information "* $fileName"
                    $changedFile = $True
                }

                Write-Information "   - Removed $replacement comment"
            }
        }

        $replacementText = '${Start}' + $emptyLine + '${End}'
        $updatedContent = $content -replace $removeBlankLinesRegex, $replacementText
        if($content -ne $updatedContent)
        {
            $content = $updatedContent
            if($changedFile -eq $False) {
                Write-Information "* $fileName"
                $changedFile = $True
            }

            Write-Information "   - Removed blank lines (end tag)"
        }

        $replacementText = '${Start}' + $emptyLine + '${End}'
        $updatedContent = $content -replace $removeBlankLines2Regex, $replacementText
        if($content -ne $updatedContent)
        {
            $content = $updatedContent
            if($changedFile -eq $False) {
                Write-Information "* $fileName"
                $changedFile = $True
            }

            Write-Information "   - Removed blank lines (single tag)"
        }

        if($content -ne $originalContent) {
            $changed = $true
            Set-Content -Path $fileName -Value $content
        }
    }

    return $changed
}


Export-ModuleMember -Function Resharper_ConvertSuppressionCommentToSuppressMessage