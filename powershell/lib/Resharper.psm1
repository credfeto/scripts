function Resharper_ConvertSuppressionCommentToSuppressMessage {  
param (
    [string] $sourceFolder = $(throw "Resharper_ConvertSuppressionCommentToSuppressMessage: sourceFolder not specified")
    )
    
    Log -message "* Changing Resharper disable once comments to SuppressMessage"
    Log -message "  - Folder: $sourceFolder"

    [string]$emptyLine = [char]13 + [char]10

    [string]$linesToRemoveRegex = "(?<LinesToRemove>((\r\n){2,}))"
    [string]$suppressMessageRegex = "(?<End>\s+\[(System\.Diagnostics\.CodeAnalysis\.)?SuppressMessage)"
    [string]$removeBlankLinesRegex = "(?ms)" +  "(?<Start>(^((\s+)///\s+</(.*?)\>)))" + $linesToRemoveRegex + $suppressMessageRegex
    [string]$removeBlankLines2Regex = "(?ms)" + "(?<Start>(^((\s+)///\s+<(.*?)/\>)))" + $linesToRemoveRegex + $suppressMessageRegex

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

    [bool]$changed = $false
    $files = Get-ChildItem -Path $sourceFolder -Filter "*.cs" -Recurse
    ForEach($file in $files) {
        [string]$fileName = $file.FullName

        [string]$content = Get-Content -Path $fileName -Raw
        [string]$originalContent = $content
        [string]$updatedContent = $content

        [bool]$changedFile = $False

        ForEach($replacement in $replacements) {
            if($replacement -eq $null) {
                continue
            }
            
            [string]$code = $replacement.Replace(".", "\.")
            [string]$regex = "//\s+ReSharper\s+disable\s+once\s+$code"
            [string]$replacementText = "[System.Diagnostics.CodeAnalysis.SuppressMessage(""ReSharper"", ""$replacement"", Justification=""TODO: Review"")]"

            [string]$updatedContent = $content -replace $regex, $replacementText
            if($content -ne $updatedContent)
            {
                [string]$content = $updatedContent
                if($changedFile -eq $False) {
                    Log -message "* $fileName"
                    [bool]$changedFile = $True
                }

                Log -message "   - Changed $replacement comment to SuppressMessage"
            }
        }

        ForEach($replacement in $deletions) {
            if($replacement -eq $null) {
                continue
            }

            [string]$code = $replacement.Replace(".", "\.")
            [string]$regex = "//\s+ReSharper\s+disable\s+once\s+$code"
            [string]$replacementText = ""

            [string]$updatedContent = $content -replace $regex, $replacementText
            if($content -ne $updatedContent)
            {
                [string]$content = $updatedContent
                if($changedFile -eq $False) {
                    Log -message "* $fileName"
                    [bool]$changedFile = $True
                }

                Log -message "   - Removed $replacement comment"
            }
        }

        [string]$replacementText = '${Start}' + $emptyLine + '${End}'
        [string]$updatedContent = $content -replace $removeBlankLinesRegex, $replacementText
        if($content -ne $updatedContent)
        {
            [string]$content = $updatedContent
            if($changedFile -eq $False) {
                Log -message "* $fileName"
                [bool]$changedFile = $True
            }

            Log -message "   - Removed blank lines (end tag)"
        }

        [string]$replacementText = '${Start}' + $emptyLine + '${End}'
        [string]$updatedContent = $content -replace $removeBlankLines2Regex, $replacementText
        if($content -ne $updatedContent)
        {
            [string]$content = $updatedContent
            if($changedFile -eq $False) {
                Log -message "* $fileName"
                [bool]$changedFile = $True
            }

            Log -message "   - Removed blank lines (single tag)"
        }

        if($content -ne $originalContent) {
            [bool]$changed = $true
            Set-Content -Path $fileName -Value $content
        }
    }

    return $changed
}


Export-ModuleMember -Function Resharper_ConvertSuppressionCommentToSuppressMessage
