<xsl:stylesheet xmlns="http://www.w3.org/1999/xhtml"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    xmlns:page="http://schema.primaresearch.org/PAGE/gts/pagecontent/2013-07-15"
    xmlns:acdh="https://vocabs.acdh.oeaw.ac.at/schema#" version="2.0" exclude-result-prefixes="#all">

    <xsl:output encoding="UTF-8" media-type="text/xml" method="xml" version="1.0" indent="yes" omit-xml-declaration="yes"/>

    <!-- Function to convert number to Roman numeral -->
    <xsl:function name="acdh:toRoman" as="xs:string">
        <xsl:param name="num" as="xs:integer"/>
        <xsl:variable name="romanMap" as="element()*">
            <r n="1000" s="M"/><r n="900" s="CM"/><r n="500" s="D"/><r n="400" s="CD"/>
            <r n="100" s="C"/><r n="90" s="XC"/><r n="50" s="L"/><r n="40" s="XL"/>
            <r n="10" s="X"/><r n="9" s="IX"/><r n="5" s="V"/><r n="4" s="IV"/><r n="1" s="I"/>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="$num le 0">
                <xsl:sequence select="''"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="match" select="$romanMap[xs:integer(@n) le $num][1]"/>
                <xsl:sequence select="string-join(($match/@s, acdh:toRoman($num - xs:integer($match/@n))), '')"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- Helper function to extract year from TEI (same fallback logic as coverageIdentifierYear) -->
    <xsl:function name="acdh:extractYear" as="xs:string">
        <xsl:param name="tei" as="element(tei:TEI)"/>
        <xsl:variable name="origDate" select="($tei//tei:msContents/tei:p/tei:origDate)[1]"/>
        <xsl:variable name="origDateWhen" select="normalize-space(string($origDate/@when))"/>
        <xsl:variable name="origDateNotBefore" select="normalize-space(string($origDate/@notBefore))"/>
        <xsl:variable name="origDateNotAfter" select="normalize-space(string($origDate/@notAfter))"/>
        <xsl:variable name="origDateFrom" select="normalize-space(string($origDate/@from))"/>
        <xsl:variable name="origDateTo" select="normalize-space(string($origDate/@to))"/>
        <xsl:variable name="biblDateRaw" select="normalize-space(($tei//tei:sourceDesc//tei:bibl/tei:date[1]/text(), $tei//tei:sourceDesc//tei:bibl/tei:date[1])[1])"/>
        <xsl:variable name="biblYear" select="if (matches($biblDateRaw, '[0-9]{4}')) then replace($biblDateRaw, '^.*?([0-9]{4}).*$', '$1') else $biblDateRaw"/>
        <xsl:variable name="origDateYear" select="if ($origDateWhen and matches($origDateWhen, '^-?\d{4}')) then replace($origDateWhen, '^(-?\d{4}).*$', '$1') else ''"/>
        <xsl:variable name="startYear" select="if ($origDateNotBefore and matches($origDateNotBefore, '^-?\d{4}')) then replace($origDateNotBefore, '^(-?\d{4}).*$', '$1') else if ($origDateFrom and matches($origDateFrom, '^-?\d{4}')) then replace($origDateFrom, '^(-?\d{4}).*$', '$1') else ''"/>
        <xsl:variable name="endYear" select="if ($origDateNotAfter and matches($origDateNotAfter, '^-?\d{4}')) then replace($origDateNotAfter, '^(-?\d{4}).*$', '$1') else if ($origDateTo and matches($origDateTo, '^-?\d{4}')) then replace($origDateTo, '^(-?\d{4}).*$', '$1') else ''"/>
        <xsl:sequence select="if (string-length($origDateYear) &gt; 0) then $origDateYear else if (string-length($startYear) &gt; 0 and string-length($endYear) &gt; 0 and $startYear = $endYear) then $startYear else if (string-length($startYear) &gt; 0) then $startYear else if (string-length($endYear) &gt; 0) then $endYear else if (normalize-space($biblYear)) then $biblYear else ''"/>
    </xsl:function>

    <xsl:template match="/">
        <xsl:variable name="constants" select="acdh:ACDH/acdh:RepoObject/*"/>
        <xsl:variable name="constantsMeta" select="acdh:ACDH/acdh:MetaObject/*"/>
        <xsl:variable name="constantsEdition" select="acdh:ACDH/acdh:EditionObject/*"/>
        <xsl:variable name="constantsImg" select="acdh:ACDH/acdh:ImgObject/*"/>
        <xsl:variable name="constantsDer" select="acdh:ACDH/acdh:DerivateObject/*"/>
        <xsl:variable name="constantsPage" select="acdh:ACDH/acdh:PageObject/*"/>
        <!-- NOTE: collection() order is not guaranteed; sort deterministically by TEI @xml:id -->
        <xsl:variable name="allTEIs" as="element(tei:TEI)*">
            <xsl:perform-sort select="collection('../data/editions?select=*.xml')//tei:TEI">
                <xsl:sort select="string(@xml:id)" order="ascending"/>
            </xsl:perform-sort>
        </xsl:variable>
        <xsl:variable name="TopColId">
            <xsl:value-of select="string(.//acdh:TopCollection/@rdf:about)"/>
        </xsl:variable>
        <xsl:variable name="Meta">
            <xsl:value-of select="concat($TopColId, '/meta')"/>
        </xsl:variable>
        <xsl:variable name="Editions">
            <xsl:value-of select="concat($TopColId, '/editions')"/>
        </xsl:variable>
        <xsl:variable name="Facsimiles">
            <xsl:value-of select="concat($TopColId, '/masters')"/>
        </xsl:variable>
         <xsl:variable name="Derivates">
            <xsl:value-of select="concat($TopColId, '/derivates')"/>
        </xsl:variable>
        <xsl:variable name="PageXml">
            <xsl:value-of select="concat($TopColId, '/pagexml')"/>
        </xsl:variable>

        <!-- NOTE: We do not chain top-level collections with hasNextItem.
             ARCHE validation expects collections to use hasNextItem to point to their first child. -->
        <!-- ARCHE requires acdh:hasNextItem for Kulturpool Collections.
             Instead of minting artificial "end" resources, loop the last volume collection
             back to the first volume collection. -->
        <xsl:variable name="firstTEIWithFacsimile" as="element(tei:TEI)?"
            select="($allTEIs[.//tei:facsimile/tei:surface/tei:graphic[@url][normalize-space(@url)][not(starts-with(@url, 'http'))]])[1]"/>
        <xsl:variable name="firstVolumeId">
            <xsl:if test="$firstTEIWithFacsimile">
                <xsl:variable name="rawXmlId" select="normalize-space(string($firstTEIWithFacsimile/@xml:id))"/>
                <xsl:variable name="rawDocName" select="replace(replace(base-uri($firstTEIWithFacsimile), '^.*[\\/]', ''), '\.[xX][mM][lL]$', '')"/>
                <xsl:choose>
                    <xsl:when test="string-length($rawXmlId) &gt; 0">
                        <xsl:variable name="lowerId" select="lower-case($rawXmlId)"/>
                        <xsl:choose>
                            <xsl:when test="ends-with($lowerId, '.xml')">
                                <xsl:value-of select="substring($rawXmlId, 1, string-length($rawXmlId) - 4)"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="$rawXmlId"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="$rawDocName"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:if>
        </xsl:variable>
        <xsl:variable name="firstVolumeCol" as="xs:string"
            select="if (normalize-space($firstVolumeId)) then concat($Facsimiles, '/', replace(normalize-space($firstVolumeId), '\.[xX][mM][lL]$', '')) else ''"/>
        <xsl:variable name="firstVolumeColBis" as="xs:string"
            select="if (normalize-space($firstVolumeId)) then concat($Derivates, '/', replace(normalize-space($firstVolumeId), '\.[xX][mM][lL]$', '')) else ''"/>
        <rdf:RDF xmlns:acdh="https://vocabs.acdh.oeaw.ac.at/schema#">
            <acdh:TopCollection>
                <xsl:attribute name="rdf:about">
                    <xsl:value-of select=".//acdh:TopCollection/@rdf:about"/>
                </xsl:attribute>
                <xsl:for-each select=".//node()[parent::acdh:TopCollection]">
                    <xsl:copy-of select="."/>
                </xsl:for-each>
            </acdh:TopCollection>

            <xsl:for-each select=".//node()[parent::acdh:MetaAgents]">
                <xsl:copy-of select="."/>
            </xsl:for-each>

            <xsl:for-each select=".//acdh:Collection[@rdf:about=$Editions]">
                <acdh:Collection>
                    <xsl:attribute name="rdf:about">
                        <xsl:value-of select="@rdf:about"/>
                    </xsl:attribute>
                    <xsl:copy-of select="$constants"/>
                    <!-- <xsl:copy-of select="$constantsEdition"/> -->
                    <xsl:copy-of select=".//acdh:*"/>
                </acdh:Collection>
            </xsl:for-each>

            <xsl:for-each select=".//acdh:Collection[@rdf:about=$Meta]">
                <acdh:Collection>
                    <xsl:attribute name="rdf:about">
                        <xsl:value-of select="@rdf:about"/>
                    </xsl:attribute>
                    <acdh:hasContributor rdf:resource="https://id.acdh.oeaw.ac.at/fsanzlazaro"/>
                    <acdh:hasMetadataCreator rdf:resource="https://id.acdh.oeaw.ac.at/fsanzlazaro"/>
                    <xsl:copy-of select="$constants"/>
                    <!-- <xsl:copy-of select="$constantsMeta"/> -->
                    <xsl:copy-of select=".//acdh:*"/>
                </acdh:Collection>
            </xsl:for-each>

            <xsl:for-each select=".//acdh:Collection[@rdf:about=$Facsimiles]">
                <acdh:Collection>
                    <xsl:attribute name="rdf:about">
                        <xsl:value-of select="@rdf:about"/>
                    </xsl:attribute>
                    <!-- <acdh:hasAccessRestriction rdf:resource="https://vocabs.acdh.oeaw.ac.at/archeaccessrestrictions/public"/> -->
                    <xsl:copy-of select="$constants"/>
                    <!-- <xsl:copy-of select="$constantsImg"/> -->
                    <xsl:copy-of select=".//acdh:*"/>
                </acdh:Collection>
            </xsl:for-each>
            
             <xsl:for-each select=".//acdh:Collection[@rdf:about=$Derivates]">
                <acdh:Collection>
                    <xsl:attribute name="rdf:about">
                        <xsl:value-of select="@rdf:about"/>
                    </xsl:attribute>
                    <!-- <acdh:hasAccessRestriction rdf:resource="https://vocabs.acdh.oeaw.ac.at/archeaccessrestrictions/public"/> -->
                    <xsl:copy-of select="$constants"/>
                    <!-- <xsl:copy-of select="$constantsImg"/> -->
                    <xsl:copy-of select=".//acdh:*"/>
                </acdh:Collection>
            </xsl:for-each>

            <xsl:for-each select=".//acdh:Collection[@rdf:about=$PageXml]">
                <acdh:Collection>
                    <xsl:attribute name="rdf:about">
                        <xsl:value-of select="@rdf:about"/>
                    </xsl:attribute>
                    <xsl:copy-of select="$constants"/>
                    <xsl:copy-of select=".//acdh:*[not(self::acdh:hasAppliedMethodDescription)]"/>
                </acdh:Collection>
            </xsl:for-each>

            <xsl:for-each select="$allTEIs">
                <!-- Compute volumeId early so it can be used for the edition URI too -->
                <xsl:variable name="rawXmlId" select="normalize-space(string(@xml:id))"/>
                <xsl:variable name="rawDocName" select="replace(replace(base-uri(.), '^.*[\\/]', ''), '\.[xX][mM][lL]$', '')"/>
                <xsl:variable name="volumeId">
                    <xsl:choose>
                        <xsl:when test="string-length($rawXmlId) &gt; 0">
                            <xsl:variable name="lowerId" select="lower-case($rawXmlId)"/>
                            <xsl:choose>
                                <xsl:when test="ends-with($lowerId, '.xml')">
                                    <xsl:value-of select="substring($rawXmlId, 1, string-length($rawXmlId) - 4)"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="$rawXmlId"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$rawDocName"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="id" select="concat(string($Editions), '/', normalize-space(string($volumeId)))"/>
                <xsl:variable name="teiPos" select="position()"/>
                <xsl:variable name="nextTEI" select="$allTEIs[$teiPos + 1]"/>
                <xsl:variable name="currentTEI" select="."/>
                <!-- Compute Roman numeral suffix for duplicate years -->
                <xsl:variable name="currentYear" select="acdh:extractYear(.)"/>
                <xsl:variable name="teisWithSameYear" select="$allTEIs[acdh:extractYear(.) = $currentYear]"/>
                <xsl:variable name="countSameYear" select="count($teisWithSameYear)"/>
                <!-- Use sorted-sequence position instead of &lt;&lt; (document-order), which is arbitrary across collection() documents -->
                <xsl:variable name="positionInYear" select="count($allTEIs[position() &lt; $teiPos][acdh:extractYear(.) = $currentYear]) + 1"/>
                <xsl:variable name="romanSuffix" select="if ($countSameYear &gt; 1) then concat(' | ', acdh:toRoman($positionInYear)) else ''"/>
                <xsl:variable name="origDate" select="(.//tei:msContents/tei:p/tei:origDate)[1]"/>
                <xsl:variable name="origDateWhen" select="normalize-space(string($origDate/@when))"/>
                <xsl:variable name="origDateNotBefore" select="normalize-space(string($origDate/@notBefore))"/>
                <xsl:variable name="origDateNotAfter" select="normalize-space(string($origDate/@notAfter))"/>
                <xsl:variable name="origDateFrom" select="normalize-space(string($origDate/@from))"/>
                <xsl:variable name="origDateTo" select="normalize-space(string($origDate/@to))"/>
                <!-- Fallback year source: TEI sourceDesc/bibl/date (many files have no msContents/origDate) -->
                <xsl:variable name="biblDateRaw" select="normalize-space((.//tei:sourceDesc//tei:bibl/tei:date[1]/text(), .//tei:sourceDesc//tei:bibl/tei:date[1])[1])"/>
                <xsl:variable name="biblYear" select="if (matches($biblDateRaw, '[0-9]{4}')) then replace($biblDateRaw, '^.*?([0-9]{4}).*$', '$1') else $biblDateRaw"/>
                <xsl:variable name="contentDescriptionNodes" select=".//tei:msContents/tei:p[not(tei:origDate)]"/>
                <xsl:variable name="origDateDescription" select="normalize-space(string-join($contentDescriptionNodes//text(), ' '))"/>
                <xsl:variable name="shelfmark" select="concat('AT-WSTLA ', normalize-space(string((.//tei:teiHeader/tei:fileDesc/tei:sourceDesc//tei:msIdentifier/tei:idno[@type='shelfmark'])[1])))"/>
                <!-- Kämmerer extraction: find respStmt with resp matching Kämmerer variants -->
                <xsl:variable name="kaemmererRespStmts" select=".//tei:titleStmt/tei:respStmt[some $r in tei:resp satisfies matches(normalize-space($r), '[Kk]ämmerer|[Kk]aemmerer', 'i')]"/>
                <!-- Prefer (Ober)kämmerer entry if present, otherwise take first entry -->
                <xsl:variable name="selectedKaemmererRespStmt" select="if ($kaemmererRespStmts[some $r in tei:resp satisfies normalize-space($r) = '(Ober)kämmerer']) then $kaemmererRespStmts[some $r in tei:resp satisfies normalize-space($r) = '(Ober)kämmerer'][1] else $kaemmererRespStmts[1]"/>
                <xsl:variable name="kaemmererRespText" select="normalize-space(($selectedKaemmererRespStmt/tei:resp[matches(normalize-space(.), '[Kk]ämmerer|[Kk]aemmerer', 'i')])[1])"/>
                <!-- If resp is (Ober)kämmerer, set kaemmerer to Oberkämmerer, otherwise Kämmerer -->
                <xsl:variable name="kaemmerer" select="if ($kaemmererRespText = '(Ober)kämmerer') then 'Oberkämmerer' else if (string-length($kaemmererRespText) &gt; 0) then 'Kämmerer' else ''"/>
                <xsl:variable name="kaemmererName" select="normalize-space(($selectedKaemmererRespStmt/tei:persName)[1])"/>
                <xsl:variable name="origDateYear" select="if ($origDateWhen and matches($origDateWhen, '^-?\d{4}')) then replace($origDateWhen, '^(-?\d{4}).*$', '$1') else ''"/>
                <xsl:variable name="startYear" select="if ($origDateNotBefore and matches($origDateNotBefore, '^-?\d{4}')) then replace($origDateNotBefore, '^(-?\d{4}).*$', '$1') else if ($origDateFrom and matches($origDateFrom, '^-?\d{4}')) then replace($origDateFrom, '^(-?\d{4}).*$', '$1') else ''"/>
                <xsl:variable name="endYear" select="if ($origDateNotAfter and matches($origDateNotAfter, '^-?\d{4}')) then replace($origDateNotAfter, '^(-?\d{4}).*$', '$1') else if ($origDateTo and matches($origDateTo, '^-?\d{4}')) then replace($origDateTo, '^(-?\d{4}).*$', '$1') else ''"/>
                <xsl:variable name="coverageIdentifierYear" select="if (string-length($origDateYear) &gt; 0) then $origDateYear else if (string-length($startYear) &gt; 0 and string-length($endYear) &gt; 0 and $startYear = $endYear) then $startYear else if (string-length($startYear) &gt; 0) then $startYear else if (string-length($endYear) &gt; 0) then $endYear else if (normalize-space($biblYear)) then $biblYear else ''"/>
                <xsl:variable name="coverageIdentifierUri" select="if (string-length($coverageIdentifierYear) &gt; 0 and $coverageIdentifierYear castable as xs:integer and xs:integer($coverageIdentifierYear) &gt;= 1500) then 'https://n2t.net/ark:/99152/p0qhb66' else 'https://n2t.net/ark:/99152/p0qhb66'"/>
                <xsl:variable name="coverageElements">
                    <acdh:hasTag xml:lang="und">TEXT</acdh:hasTag>
	            <xsl:choose>
                        <xsl:when test="$origDateYear">
                            <acdh:hasTemporalCoverage xml:lang="und">
                                <xsl:value-of select="$origDateYear"/>
                            </acdh:hasTemporalCoverage>
                        </xsl:when>
                        <xsl:when test="$startYear and $endYear and $startYear = $endYear">
                            <acdh:hasTemporalCoverage xml:lang="und">
                                <xsl:value-of select="$startYear"/>
                            </acdh:hasTemporalCoverage>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:if test="$origDateNotBefore">
                                <acdh:hasCoverageStartDate>
                                    <xsl:value-of select="$origDateNotBefore"/>
                                </acdh:hasCoverageStartDate>
                            </xsl:if>
                            <xsl:if test="not($origDateNotBefore) and $origDateFrom">
                                <acdh:hasCoverageStartDate>
                                    <xsl:value-of select="$origDateFrom"/>
                                </acdh:hasCoverageStartDate>
                            </xsl:if>
                            <xsl:if test="$origDateNotAfter">
                                <acdh:hasCoverageEndDate>
                                    <xsl:value-of select="$origDateNotAfter"/>
                                </acdh:hasCoverageEndDate>
                            </xsl:if>
                            <xsl:if test="not($origDateNotAfter) and $origDateTo">
                                <acdh:hasCoverageEndDate>
                                    <xsl:value-of select="$origDateTo"/>
                                </acdh:hasCoverageEndDate>
                            </xsl:if>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="coverageIdentifierElements">
                    <xsl:if test="string-length($coverageIdentifierYear) &gt; 0">
                        <acdh:hasTemporalCoverageIdentifier>
				            <xsl:value-of select="$coverageIdentifierUri"/>
                        </acdh:hasTemporalCoverageIdentifier>
                    </xsl:if>
                </xsl:variable>
                <!-- Original descriptionElements kept for non-TEI resources -->
                <xsl:variable name="descriptionElementsOrig">
                    <xsl:if test="$origDateDescription">
                        <acdh:hasDescription xml:lang="de">
                            <xsl:value-of select="$origDateDescription"/>
                        </acdh:hasDescription>
                    </xsl:if>
                </xsl:variable>
                <xsl:variable name="identifierElements">
                    <xsl:if test="$shelfmark">
                        <acdh:hasNonLinkedIdentifier>
                            <xsl:value-of select="$shelfmark"/>
                        </acdh:hasNonLinkedIdentifier>
                    </xsl:if>
                </xsl:variable>
                <!-- volumeId, rawXmlId, rawDocName are now computed at the top of the for-each loop -->
                <xsl:variable name="isTargetVolume" as="xs:boolean" select="starts-with(normalize-space(string($volumeId)), 'WSTLA-OKA-B1-1-')"/>
                <!-- Ensure no trailing .xml in volumeCol even if volumeId may contain it -->
                <xsl:variable name="volumeCol" select="concat($Facsimiles, '/', replace($volumeId, '\.[xX][mM][lL]$', ''))"/>
                <xsl:variable name="volumeColBis" select="concat($Derivates, '/', replace($volumeId, '\.[xX][mM][lL]$', ''))"/>
                <!-- Subcollection title base:
                     - Prefer the TEI's descriptive "main" title (de) to mirror the TEI file title
                     - If the title is just a self number (e.g. 103), use "Kammeramtsrechnung {year} ({selfnumber})" with year from //sourceDesc/bibl/date
                -->
                <xsl:variable name="teiTitleMain" select="normalize-space((.//tei:titleStmt/tei:title[@type='main'][@level='a'][@xml:lang='de'], .//tei:titleStmt/tei:title[@type='main'][@level='a'], .//tei:titleStmt/tei:title[@type='main'][@xml:lang='de'], .//tei:titleStmt/tei:title[@type='main'])[1])"/>
                <xsl:variable name="teiTitleDesc" select="normalize-space((.//tei:titleStmt/tei:title[@type='desc'][@level='a'][@xml:lang='de'], .//tei:titleStmt/tei:title[@type='desc'][@level='a'], .//tei:titleStmt/tei:title[@type='desc'][@xml:lang='de'], .//tei:titleStmt/tei:title[@type='desc'])[1])"/>
                <xsl:variable name="teiTitleCandidate" select="if (string-length($teiTitleMain) &gt; 0) then $teiTitleMain else if (string-length($teiTitleDesc) &gt; 0) then $teiTitleDesc else $volumeId"/>
                <xsl:variable name="shelfmarkDigits" select="if ($shelfmark and matches($shelfmark, '[0-9]+$')) then replace($shelfmark, '^.*?([0-9]+)$', '$1') else ''"/>
                <xsl:variable name="selfNumber" select="if (matches($teiTitleCandidate, '^[0-9]+$')) then $teiTitleCandidate else $shelfmarkDigits"/>
                <xsl:variable name="volumeTitleBase">
                    <xsl:choose>
                        <xsl:when test="(matches($teiTitleCandidate, '^[0-9]+$') or matches($teiTitleCandidate, '^WSTLA-OKA-B1-1-[0-9]+-1$'))">
                            <xsl:variable name="yearForFallbackRaw" select="normalize-space((.//tei:sourceDesc//tei:bibl/tei:date[1], .//tei:date[1])[1])"/>
                            <xsl:variable name="yearForFallback" select="replace($yearForFallbackRaw, '^.*?([0-9]{4}).*$', '$1')"/>
                            <xsl:choose>
                                <xsl:when test="matches($yearForFallback, '[0-9]{4}')">
                                    <xsl:value-of select="concat('Oberkammeramtsrechnung | ', $yearForFallback, ' (', $teiTitleCandidate, ')')"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="concat('Oberkammeramtsrechnung (', $teiTitleCandidate, ')')"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:when>
                        <xsl:when test="string-length($teiTitleMain) &gt; 0 and not(matches($teiTitleMain, '^WSTLA-OKA-B1-1-[0-9]+-1$')) and not(matches($teiTitleMain, '^[0-9]+$'))">
                            <xsl:value-of select="$teiTitleMain"/>
                        </xsl:when>
                        <xsl:when test="string-length($teiTitleDesc) &gt; 0 and not(matches($teiTitleDesc, '^WSTLA-OKA-B1-1-[0-9]+-1$')) and not(matches($teiTitleDesc, '^[0-9]+$'))">
                            <xsl:value-of select="$teiTitleDesc"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$volumeId"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="volumeLabel" select="normalize-space(string($volumeTitleBase))"/>
                <!-- descriptionElements for xml-tei resources with kämmerer info -->
                <xsl:variable name="descriptionElements">
                    <xsl:choose>
                        <xsl:when test="string-length($kaemmerer) &gt; 0 and string-length($kaemmererName) &gt; 0 and string-length(normalize-space($origDateDescription)) &gt; 0">
                            <xsl:value-of select="concat($kaemmerer, ': ', $kaemmererName, '&#10; &#10; Inhalt: ', $origDateDescription)"/>
                        </xsl:when>
                        <xsl:when test="string-length($kaemmerer) &gt; 0 and string-length($kaemmererName) &gt; 0">
                            <xsl:value-of select="concat($kaemmerer, ': ', $kaemmererName)"/>
                        </xsl:when>
                        <xsl:when test="string-length(normalize-space($origDateDescription)) &gt; 0">
                            <xsl:value-of select="concat('Inhalt: ', $origDateDescription)"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="concat('Digitalisierte Seiten des Bandes ', $volumeLabel)"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:variable name="graphics" select=".//tei:facsimile/tei:surface/tei:graphic[@url][normalize-space(@url)][not(starts-with(@url, 'http'))]"/>
                <xsl:variable name="graphicsSorted" as="element(tei:graphic)*">
                    <xsl:perform-sort select="$graphics">
                        <xsl:sort select="replace(replace(string(@url), '^.*[\\/]', ''), '^[\\./]+', '')" order="ascending"/>
                    </xsl:perform-sort>
                </xsl:variable>

                <acdh:Resource rdf:about="{$id}">
                    <acdh:hasLanguage rdf:resource="https://vocabs.acdh.oeaw.ac.at/iso6393/deu"/>
                    <acdh:isPartOf rdf:resource="{$Editions}"/>
                    <acdh:hasTitle xml:lang="de">
                        <xsl:value-of select="concat('Oberkammeramtsrechnung | ', $coverageIdentifierYear, $romanSuffix, ' (TEI-XML-Edition)')"/>
                    </acdh:hasTitle>
                    <acdh:hasSchema xml:lang="und">
                         <xsl:value-of select="$TopColId/schema.odd" />
                    </acdh:hasSchema>
                    <acdh:hasSchema xml:lang="und">
                        <xsl:value-of select="$TopColId/schema.rng" />
                   </acdh:hasSchema>
                    <!-- <acdh:isObjectMetadataFor rdf:resource="{$Derivates}/{$volumeId}"/>
                    <acdh:isObjectMetadataFor rdf:resource="{$Facsimiles}/{$volumeId}"/> -->
                    <xsl:copy-of select="$coverageElements/*"/>
                    <xsl:copy-of select="$coverageIdentifierElements/*"/>
                    <acdh:hasDescription xml:lang="de">
                        <xsl:value-of select="$descriptionElements"/>
                    </acdh:hasDescription>
                    <xsl:copy-of select="$identifierElements/*"/>
                    <xsl:copy-of select="$constants"/>
                    <xsl:copy-of select="$constantsEdition"/>
                </acdh:Resource>

                <xsl:if test="exists($graphicsSorted)">
                    <xsl:variable name="nextTEIWithFacsimile" select="($allTEIs[position() &gt; $teiPos][.//tei:facsimile/tei:surface/tei:graphic[@url][normalize-space(@url)][not(starts-with(@url, 'http'))]])[1]"/>
                    <xsl:variable name="nextVolumeId">
                        <xsl:if test="$nextTEIWithFacsimile">
                            <xsl:variable name="rawXmlId" select="normalize-space(string($nextTEIWithFacsimile/@xml:id))"/>
                            <xsl:variable name="rawDocName" select="replace(replace(base-uri($nextTEIWithFacsimile), '^.*[\\/]', ''), '\.[xX][mM][lL]$', '')"/>
                            <xsl:choose>
                                <xsl:when test="string-length($rawXmlId) &gt; 0">
                                    <xsl:variable name="lowerId" select="lower-case($rawXmlId)"/>
                                    <xsl:choose>
                                        <xsl:when test="ends-with($lowerId, '.xml')">
                                            <xsl:value-of select="substring($rawXmlId, 1, string-length($rawXmlId) - 4)"/>
                                        </xsl:when>
                                        <xsl:otherwise>
                                            <xsl:value-of select="$rawXmlId"/>
                                        </xsl:otherwise>
                                    </xsl:choose>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="$rawDocName"/>
                                </xsl:otherwise>
                            </xsl:choose>
                        </xsl:if>
                    </xsl:variable>
                    <xsl:variable name="nextVolumeCol">
                        <xsl:if test="$nextTEIWithFacsimile and normalize-space($nextVolumeId) and starts-with(normalize-space($nextVolumeId), 'WSTLA-OKA-B1-1-')">
                            <xsl:value-of select="concat($Facsimiles, '/', replace($nextVolumeId, '\.[xX][mM][lL]$', ''))"/>
                        </xsl:if>
                    </xsl:variable>
                    <xsl:variable name="nextVolumeColBis">
                        <xsl:if test="$nextTEIWithFacsimile and normalize-space($nextVolumeId) and starts-with(normalize-space($nextVolumeId), 'WSTLA-OKA-B1-1-')">
                            <xsl:value-of select="concat($Derivates, '/', replace($nextVolumeId, '\.[xX][mM][lL]$', ''))"/>
                        </xsl:if>
                    </xsl:variable>
                    <xsl:variable name="nextVolumeFirstGraphic">
                        <xsl:if test="$nextTEIWithFacsimile">
                            <xsl:value-of select="concat(normalize-space($nextVolumeCol), '/', encode-for-uri(replace(replace($nextTEIWithFacsimile//tei:facsimile/tei:surface/tei:graphic[@url][normalize-space(@url)][not(starts-with(@url, 'http'))][1]/@url, '^.*[\\/]', ''), '^[\\./]+', '')))"/>
                        </xsl:if>
                    </xsl:variable>
                    <xsl:variable name="nextVolumeFirstGraphicBis">
                        <xsl:if test="$nextTEIWithFacsimile">
                            <xsl:value-of select="concat(normalize-space($nextVolumeColBis), '/', encode-for-uri(replace(replace($nextTEIWithFacsimile//tei:facsimile/tei:surface/tei:graphic[@url][normalize-space(@url)][not(starts-with(@url, 'http'))][1]/@url, '^.*[\\/]', ''), '^[\\./]+', '')))"/>
                        </xsl:if>
                    </xsl:variable>
                    <xsl:variable name="afterThisVolumeMasters" select="if ($nextTEIWithFacsimile) then normalize-space($nextVolumeCol) else $Derivates"/>
                    <xsl:variable name="afterThisVolumeDerivates" select="if ($nextTEIWithFacsimile) then normalize-space($nextVolumeColBis) else 'https://id.acdh.oeaw.ac.at//wstla_/wstla_oka-rechnungsbuecher-stadtwien/logo_okar.png'"/>
                    <!-- Find first image in this facsimile subcollection -->
                    <xsl:variable name="firstGraphic">
                        <xsl:if test="count($graphicsSorted) &gt; 0">
                                <xsl:value-of select="concat($volumeCol, '/', encode-for-uri(replace(replace($graphicsSorted[1]/@url, '^.*[\\/]', ''), '^[\./]+', '')))"/>
                        </xsl:if>
                    </xsl:variable>
                    <xsl:variable name="firstGraphicBis">
                        <xsl:if test="count($graphicsSorted) &gt; 0">
                            <xsl:value-of select="concat($volumeColBis, '/', encode-for-uri(replace(replace($graphicsSorted[1]/@url, '^.*[\\/]', ''), '^[\./]+', '')))"/>
                        </xsl:if>
                    </xsl:variable>
                    <!-- Keep hasNextItem only within volume subcollections and their members.
                        Bridge volumes via the last image; loop the last volume back to the first volume
                        so the chain is closed without requiring hasNextItem on the top-level collections. -->
                    <xsl:variable name="nextVolumeForMasters" select="if (normalize-space($nextVolumeCol)) then normalize-space($nextVolumeCol) else ''"/>
                    <xsl:variable name="nextVolumeForDerivates" select="if (normalize-space($nextVolumeColBis)) then normalize-space($nextVolumeColBis) else ''"/>
                    <xsl:variable name="subcollectionTitleBase" as="xs:string">
                        <xsl:choose>
                            <!-- If we had to fall back (ID-only or numeric-only), don't append the id again -->
                            <xsl:when test="matches($teiTitleCandidate, '^WSTLA-OKA-B1-1-[0-9]+-1$') or matches($teiTitleCandidate, '^[0-9]+$')">
                                <xsl:value-of select="$volumeLabel"/>
                            </xsl:when>
                            <!-- Otherwise, append the id in parentheses -->
                            <xsl:otherwise>
                                <xsl:value-of select="concat($volumeLabel, ' (', normalize-space($volumeId), ')')"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <acdh:Collection rdf:about="{$volumeCol}">
                            <!-- DEBUG: removed -->
                        <acdh:hasPid>create</acdh:hasPid>
                        <acdh:hasTitle xml:lang="de">
                            <xsl:value-of select="concat('Oberkammeramtsrechnung | ', $coverageIdentifierYear, $romanSuffix, ' (Master-Scans)')"/>
                        </acdh:hasTitle>
                        <acdh:hasDescription xml:lang="de">
                            <xsl:value-of select="$descriptionElements"/>
                        </acdh:hasDescription>
                        <acdh:hasSpatialCoverage rdf:resource="https://id.acdh.oeaw.ac.at/vienna" /> 
                        <xsl:copy-of select="$coverageElements/*"/>
                        <xsl:copy-of select="$coverageIdentifierElements/*"/>
                        <xsl:copy-of select="$identifierElements/*"/>
                        <acdh:isPartOf rdf:resource="{$Facsimiles}"/>
                        <xsl:if test="$isTargetVolume and normalize-space($firstGraphic)">
                            <acdh:hasNextItem rdf:resource="{$firstGraphic}"/>
                        </xsl:if>
                        <xsl:copy-of select="$constants"/>
                        <xsl:copy-of select="$constantsImg"/>
                    </acdh:Collection>

                    <acdh:Collection rdf:about="{$volumeColBis}">
                            <!-- DEBUG: removed -->
                        <acdh:hasPid>create</acdh:hasPid>
                        <acdh:hasTitle xml:lang="de">
                            <xsl:value-of select="concat('Oberkammeramtsrechnung | ', $coverageIdentifierYear, $romanSuffix, ' (Bearbeitete Digitalisate)')"/>
                        </acdh:hasTitle>
                        <acdh:hasUsedSoftware>Goobi Workflow</acdh:hasUsedSoftware>
                        <acdh:hasLanguage rdf:resource="https://vocabs.acdh.oeaw.ac.at/iso6393/deu"/>
                        <acdh:hasOaiSet rdf:resource="https://vocabs.acdh.oeaw.ac.at/archeoaisets/kulturpool"/>
                        <acdh:hasDescription xml:lang="de">
                            <xsl:value-of select="$descriptionElements"/>
                        </acdh:hasDescription>
                        <acdh:hasSpatialCoverage rdf:resource="https://id.acdh.oeaw.ac.at/vienna" /> 
                        <xsl:copy-of select="$coverageElements/*"/>
                        <xsl:copy-of select="$coverageIdentifierElements/*"/>
                        <xsl:copy-of select="$identifierElements/*"/>
                        <acdh:isPartOf rdf:resource="{$Derivates}"/>
                        <xsl:if test="$isTargetVolume and normalize-space($firstGraphicBis)">
                            <acdh:hasNextItem rdf:resource="{$firstGraphicBis}"/>
                        </xsl:if>
                        <xsl:copy-of select="$constants"/>
                        <xsl:copy-of select="$constantsDer"/>
                    </acdh:Collection>

                    <!-- PAGE-XML subcollection and resources -->
                    <xsl:variable name="pageXmlFolder" select="concat('../data/page/', $volumeId)"/>
                    <xsl:variable name="pageXmlColUri" select="concat($PageXml, '/', $volumeId)"/>
                    <xsl:variable name="pageXmlFiles" as="element()*">
                        <xsl:variable name="collectionUri" select="concat($pageXmlFolder, '?select=*.xml')"/>
                        <xsl:if test="doc-available(concat($pageXmlFolder, '/', $volumeId, '_00001.xml'))">
                            <xsl:perform-sort select="collection($collectionUri)/*">
                                <xsl:sort select="replace(base-uri(.), '^.*[\\/]', '')" order="ascending"/>
                            </xsl:perform-sort>
                        </xsl:if>
                    </xsl:variable>
                    
                    <xsl:if test="count($pageXmlFiles) &gt; 0">
                        <!-- Extract all model_ids from page xml files in this collection -->
                        <xsl:variable name="allModelIds" as="xs:string*">
                            <xsl:for-each select="$pageXmlFiles">
                                <xsl:variable name="creatorText" select="normalize-space(.//page:Metadata/page:Creator)"/>
                                <xsl:if test="contains($creatorText, 'model_id=')">
                                    <xsl:value-of select="replace($creatorText, '^.*model_id=([^:]+).*$', '$1')"/>
                                </xsl:if>
                            </xsl:for-each>
                        </xsl:variable>
                        <xsl:variable name="hasAnyModelId" select="count($allModelIds) &gt; 0"/>
                        <xsl:variable name="firstModelId" select="if ($hasAnyModelId) then $allModelIds[1] else ''"/>
                        <xsl:variable name="collectionMethodDesc" select="if ($hasAnyModelId) then concat('Generiert mit Transkribus sowie Korrektur ausgewählter Seiten. (Automatische Texterkennung mit Modell ', $firstModelId, ')') else 'Generiert mit Transkribus'"/>
                        <!-- Capture variables for use in nested for-each -->
                        <xsl:variable name="pageYear" select="$coverageIdentifierYear"/>
                        <xsl:variable name="pageRomanSuffix" select="$romanSuffix"/>
                        
                        <acdh:Collection rdf:about="{$pageXmlColUri}">
                            <acdh:hasPid>create</acdh:hasPid>
                            <acdh:hasTitle xml:lang="de">
                                <xsl:value-of select="concat('Oberkammeramtsrechnung | ', $coverageIdentifierYear, $romanSuffix, ' (PAGE-XML-Bechreibungen)')"/>
                            </acdh:hasTitle>
                            <acdh:hasUsedSoftware>Transkribus</acdh:hasUsedSoftware>
                            <acdh:hasLanguage rdf:resource="https://vocabs.acdh.oeaw.ac.at/iso6393/deu"/>
                            <acdh:hasDescription xml:lang="de">
                                <xsl:value-of select="$descriptionElements"/>
                            </acdh:hasDescription>
                            <acdh:hasAppliedMethodDescription xml:lang="de">
                                <xsl:value-of select="$collectionMethodDesc"/>
                            </acdh:hasAppliedMethodDescription>
                            <acdh:hasSpatialCoverage rdf:resource="https://id.acdh.oeaw.ac.at/vienna"/>
                            <xsl:copy-of select="$coverageElements/*"/>
                            <xsl:copy-of select="$coverageIdentifierElements/*"/>
                            <xsl:copy-of select="$identifierElements/*"/>
                            <acdh:isPartOf rdf:resource="{$PageXml}"/>
                            <xsl:copy-of select="$constants"/>
                            <xsl:copy-of select="$constantsPage[not(self::acdh:isPartOf)]"/>
                        </acdh:Collection>
                        
                        <!-- Individual PAGE-XML resources -->
                        <xsl:for-each select="$pageXmlFiles">
                            <xsl:variable name="pageFilename" select="replace(string(base-uri(.)), '^.*[\\/]', '')"/>
                            <xsl:variable name="pageNumber" select="format-number(position(), '00000')"/>
                            <xsl:variable name="pageResourceUri" select="concat($pageXmlColUri, '/', encode-for-uri($pageFilename))"/>
                            <xsl:variable name="creatorText" select="normalize-space(.//page:Metadata/page:Creator)"/>
                            <xsl:variable name="resourceModelId" select="if (contains($creatorText, 'model_id=')) then replace($creatorText, '^.*model_id=([^:]+).*$', '$1') else ''"/>
                            <xsl:variable name="resourceMethodDesc" select="if (string-length($resourceModelId) &gt; 0) then concat('Generiert mit Transkribus (Automatische Texterkennung mit Modell ', $resourceModelId, ')') else 'Generiert mit Transkribus'"/>
                            
                            <acdh:Resource rdf:about="{$pageResourceUri}">
                                <acdh:hasPid>create</acdh:hasPid>
                                <acdh:hasCategory rdf:resource="https://vocabs.acdh.oeaw.ac.at/archecategory/text"/>
                                <acdh:isPartOf rdf:resource="{$pageXmlColUri}"/>
                                <acdh:isSourceOf rdf:resource="{$id}"/>
                                <acdh:hasTag xml:lang="en">TEXT</acdh:hasTag>
                                <acdh:hasFormat>application/xml</acdh:hasFormat>
                                <acdh:hasTitle xml:lang="de">
                                    <xsl:value-of select="concat('Oberkammeramtsrechnung | ', $pageYear, $pageRomanSuffix, ' (PAGE-XML-Beschreibung) – ', $pageNumber)"/>
                                </acdh:hasTitle>
                                <acdh:hasAppliedMethodDescription xml:lang="de">
                                    <xsl:value-of select="$resourceMethodDesc"/>
                                </acdh:hasAppliedMethodDescription>
                                <xsl:copy-of select="$constants"/>
                                <xsl:copy-of select="$constantsPage[not(self::acdh:isPartOf)]"/>
                            </acdh:Resource>
                        </xsl:for-each>
                    </xsl:if>

                    <xsl:variable name="graphicsList" select="$graphicsSorted"/>
                    <xsl:for-each select="$graphicsSorted">
                        <xsl:variable name="graphicUrl" select="string(@url)"/>
                        <xsl:variable name="graphicFilename" select="replace(replace($graphicUrl, '^.*[\\/]', ''), '^[\\./]+', '')"/>
                        <!-- Use position() for sequential page numbering with zero-padding to 3 digits -->
                        <xsl:variable name="imageNumber" select="format-number(position(), '000')"/>
                        <xsl:variable name="effectiveId" select="concat($volumeCol, '/', encode-for-uri($graphicFilename))"/>
                        <xsl:variable name="effectiveIdbis" select="concat($volumeColBis, '/', encode-for-uri($graphicFilename))"/>
                        <xsl:variable name="width" select="string(@width)"/>
                        <xsl:variable name="height" select="string(@height)"/>
                        <xsl:variable name="extentValue">
                        <xsl:choose>
                            <xsl:when test="$width and $height">
                                <xsl:value-of select="concat($width, ' × ', $height)"/>
                            </xsl:when>
                            <xsl:when test="$width">
                                <xsl:value-of select="$width"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="$height"/>
                            </xsl:otherwise>
                        </xsl:choose>
                        </xsl:variable>
                        <!-- compute next-node position and uri; only emit hasNextItem when a next image exists -->
                        <xsl:variable name="pos" select="position()"/>
                        <xsl:variable name="nextNode" select="$graphicsSorted[$pos + 1]"/>
                        <xsl:variable name="nextGraphicUri" select="if ($nextNode) then concat($volumeCol, '/', encode-for-uri(replace(replace($nextNode/@url, '^.*[\\/]', ''), '^[\\./]+', ''))) else ''"/>
                        <xsl:variable name="nextGraphicUriBis" select="if ($nextNode) then concat($volumeColBis, '/', encode-for-uri(replace(replace($nextNode/@url, '^.*[\\/]', ''), '^[\\./]+', ''))) else ''"/>
                        <acdh:Resource rdf:about="{$effectiveId}">
                            <acdh:hasPid>create</acdh:hasPid>
                            <xsl:choose>
                                <xsl:when test="$isTargetVolume and $nextNode">
                                    <acdh:hasNextItem rdf:resource="{$nextGraphicUri}"/>
                                </xsl:when>
                            </xsl:choose>
                            <!-- <acdh:hasAccessRestriction rdf:resource="https://vocabs.acdh.oeaw.ac.at/archeaccessrestrictions/public"/> -->
                            <!-- <acdh:hasLicense rdf:resource="https://vocabs.acdh.oeaw.ac.at/archelicenses/cc-by-4-0"/> -->
                            <acdh:hasCategory rdf:resource="https://vocabs.acdh.oeaw.ac.at/archecategory/image"/>
                            <acdh:isPartOf rdf:resource="{$volumeCol}"/>
                            <acdh:hasTag xml:lang="en">TEXT</acdh:hasTag>
                            <acdh:hasFormat>image/tiff</acdh:hasFormat>
                            <acdh:hasTitle xml:lang="de">
                                <xsl:value-of select="concat('Oberkammeramtsrechnung | ', $coverageIdentifierYear, $romanSuffix, ' (Master-Scan) – ', $imageNumber)"/>
                            </acdh:hasTitle>
                            <!-- <acdh:hasUrl>
                                <xsl:value-of select="$graphicUrl"/>
                            </acdh:hasUrl> -->
                            <xsl:if test="string-length($extentValue) &gt; 0">
                                    <acdh:hasExtent xml:lang="und">
                                        <xsl:value-of select="$extentValue"/>
                                    </acdh:hasExtent>
                            </xsl:if>
                            <xsl:copy-of select="$constants"/>
                            <xsl:copy-of select="$constantsImg"/>
                        </acdh:Resource>
                        <acdh:Resource rdf:about="{$effectiveIdbis}">
                            <acdh:hasPid>create</acdh:hasPid>
                            <xsl:choose>
                                <xsl:when test="$isTargetVolume and $nextNode">
                                    <acdh:hasNextItem rdf:resource="{$nextGraphicUriBis}"/>
                                </xsl:when>
                            </xsl:choose>
                            <!-- <acdh:hasAccessRestriction rdf:resource="https://vocabs.acdh.oeaw.ac.at/archeaccessrestrictions/public"/> -->
                            <!-- <acdh:hasLicense rdf:resource="https://vocabs.acdh.oeaw.ac.at/archelicenses/cc-by-4-0"/> -->
                            <acdh:hasCategory rdf:resource="https://vocabs.acdh.oeaw.ac.at/archecategory/image"/>
                            <acdh:isPartOf rdf:resource="{$volumeColBis}"/>
                            <acdh:hasTag xml:lang="en">TEXT</acdh:hasTag>
                            <acdh:hasFormat>image/tiff</acdh:hasFormat>
                            <acdh:hasTitle xml:lang="de">
                                <xsl:value-of select="concat('Oberkammeramtsrechnung | ', $coverageIdentifierYear, $romanSuffix, ' (Bearbeitetes Digitalisat) – ', $imageNumber)"/>
                            </acdh:hasTitle>
                            <!-- <acdh:hasUrl>
                                <xsl:value-of select="$graphicUrl"/>
                            </acdh:hasUrl> -->
                            <xsl:if test="string-length($extentValue) &gt; 0">
                                    <acdh:hasExtent xml:lang="und">
                                        <xsl:value-of select="$extentValue"/>
                                    </acdh:hasExtent>
                            </xsl:if>
                            <xsl:copy-of select="$constants"/>
                            <xsl:copy-of select="$constantsImg"/>
                        </acdh:Resource>                  
                    </xsl:for-each>
                </xsl:if>
            </xsl:for-each>

            <acdh:Resource rdf:about="https://id.acdh.oeaw.ac.at/wstla_oka-rechnungsbuecher-stadtwien/logo_okar.png">
                <acdh:hasTitle xml:lang="de">Logo von „Oberkammeramtsrechnungsbücher der Stadt Wien“</acdh:hasTitle>
                <!--<acdh:hasPid>create</acdh:hasPid> -->
                <acdh:hasCategory rdf:resource="https://vocabs.acdh.oeaw.ac.at/archecategory/image"/>
                <acdh:hasFormat>image/png</acdh:hasFormat>
                <acdh:isTitleImageOf rdf:resource="https://id.acdh.oeaw.ac.at/wstla_oka-rechnungsbuecher-stadtwien"/>
                <xsl:copy-of select="$constants"/>
                <xsl:copy-of select="$constantsMeta"/>
            </acdh:Resource>
            <acdh:Metadata rdf:about="https://id.acdh.oeaw.ac.at/wstla_oka-rechnungsbuecher-stadtwien/schema.odd">
                <acdh:hasTitle xml:lang="de">TEI-XML-Schema ODD für „Oberkammeramtsrechnungsbücher der Stadt Wien“</acdh:hasTitle>
                <acdh:hasDescription xml:lang="de">XML/TEI Schema ODD für „Oberkammeramtsrechnungsbücher der Stadt Wien“</acdh:hasDescription>
                <!-- <acdh:hasPid>create</acdh:hasPid> -->
                <acdh:hasCategory rdf:resource="https://vocabs.acdh.oeaw.ac.at/archecategory/other"/>
                <acdh:isMetadataFor rdf:resource="https://id.acdh.oeaw.ac.at/wstla_oka-rechnungsbuecher-stadtwien/editions"/>
                <xsl:copy-of select="$constants"/>
                <xsl:copy-of select="$constantsMeta"/>
            </acdh:Metadata>
            <acdh:Metadata rdf:about="https://id.acdh.oeaw.ac.at/wstla_oka-rechnungsbuecher-stadtwien/schema.rng">
                <acdh:hasTitle xml:lang="de">TEI/XML Schema RNG für „Oberkammeramtsrechnungsbücher der Stadt Wien“</acdh:hasTitle>
                <acdh:hasDescription xml:lang="de">XML/TEI Schema RNG für „Oberkammeramtsrechnungsbücher der Stadt Wien“</acdh:hasDescription>
                <!-- <acdh:hasPid>create</acdh:hasPid> -->
                <acdh:hasCategory rdf:resource="https://vocabs.acdh.oeaw.ac.at/archecategory/other"/>
                <acdh:isMetadataFor rdf:resource="https://id.acdh.oeaw.ac.at/wstla_oka-rechnungsbuecher-stadtwien/editions"/>
                <!-- <acdh:hasNextItem rdf:resource="{$Facsimiles}"/> -->
                <xsl:copy-of select="$constants"/>
                <xsl:copy-of select="$constantsMeta"/>
            </acdh:Metadata>
        </rdf:RDF>
    </xsl:template>
</xsl:stylesheet>
