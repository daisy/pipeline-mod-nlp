<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:d="http://www.daisy.org/ns/pipeline/data"
    exclude-result-prefixes="xs"
    version="2.0">

  <xsl:param name="tmp-word-tag"/>
  <xsl:param name="tmp-sentence-tag"/>
  <xsl:param name="can-contain-words"/>
  <xsl:param name="special-sentences" select="''"/>
  <xsl:param name="output-ns"/>
  <xsl:param name="output-sentence-tag"/>

  <!-- The words need an additional pair (attr, val), otherwise they
       could not be identified later on, unlike the sentences which
       are identified thanks to their id. -->
  <xsl:param name="output-word-tag"/>
  <xsl:param name="word-attr" select="''"/>
  <xsl:param name="word-attr-val" select="''"/>

  <xsl:key name="sentences" match="*[@id]" use="@id"/>

  <xsl:function name="d:sentid">
    <xsl:param name="node"/>
    <xsl:value-of select="if ($node/@id) then $node/@id else concat('st', generate-id($node))"/>
  </xsl:function>

  <!--========================================================= -->
  <!-- FIND ALL THE SENTENCES' ID                               -->
  <!--========================================================= -->

  <xsl:variable name="sentence-ids-tree">
    <d:sentences>
      <xsl:apply-templates select="/*" mode="sentence-ids"/>
    </d:sentences>
  </xsl:variable>

  <xsl:template match="*" mode="sentence-ids" priority="1">
    <xsl:apply-templates select="*" mode="sentence-ids"/>
  </xsl:template>

  <xsl:template match="*[local-name() = $tmp-sentence-tag]" mode="sentence-ids" priority="2">
    <d:sentence id="{d:sentid(.)}"/>
  </xsl:template>

  <xsl:variable name="special-list" select="concat(',', $special-sentences, ',')"/>
  <xsl:template mode="sentence-ids" priority="3"
      match="*[contains($special-list, concat(',', local-name(), ',')) or (local-name() = $output-sentence-tag and count(*) = 1 and count(*[local-name() = $tmp-sentence-tag]) = 1)]">
    <d:sentence id="{d:sentid(.)}" recycled="1"/>
    <!-- Warning: a 'special-sentence', such as noteref, is unlikely
         to be stamped as 'recycled' because it is usually the child
         of a tmp:sentence (not the other way around). -->
  </xsl:template>

  <!--======================================================== -->
  <!-- INSERT THE SENTENCES USING VALID ELEMENTS COMPLIANT     -->
  <!-- WITH THE FORMAT (e.g. Zedai, DTBook)                    -->
  <!--======================================================== -->

  <xsl:template match="/" priority="2">
    <!-- <xsl:copy copy-namespaces="no"> -->
    <!--   <xsl:call-template name="copy-namespaces"/> -->
      <xsl:apply-templates select="node()"/>
    <!-- </xsl:copy> -->
    <!-- Write the list of sentences on the secondary port. -->
    <xsl:result-document href="{concat('sids', generate-id(), '.xml')}" method="xml">
     <xsl:copy-of select="$sentence-ids-tree"/>
    </xsl:result-document>
  </xsl:template>

  <xsl:template match="@*|node()" priority="1">
    <xsl:variable name="myid" select="d:sentid(.)"/>
    <xsl:variable name="entry" select="key('sentences', $myid, $sentence-ids-tree)"/>
    <xsl:choose>
      <xsl:when test="$entry and $entry/@recycled">
  	<xsl:copy copy-namespaces="no">
  	  <xsl:call-template name="copy-namespaces"/>
  	  <xsl:copy-of select="@*"/>
  	  <xsl:if test="not(@id)">
  	    <xsl:attribute name="id">
  	      <xsl:value-of select="$entry/@id"/>
  	    </xsl:attribute>
  	  </xsl:if>
  	  <xsl:apply-templates select="node()" mode="inside-sentence">
  	    <xsl:with-param name="parent-name" select="local-name()"/>
  	  </xsl:apply-templates>
  	</xsl:copy>
      </xsl:when>
      <xsl:when test="$entry">
  	<xsl:element name="{$output-sentence-tag}" namespace="{$output-ns}">
  	  <xsl:attribute name="id">
  	    <xsl:value-of select="$entry/@id"/>
  	  </xsl:attribute>
  	  <xsl:apply-templates select="node()" mode="inside-sentence">
  	    <xsl:with-param name="parent-name" select="$output-sentence-tag"/>
  	  </xsl:apply-templates>
  	</xsl:element>
      </xsl:when>
      <xsl:when test="local-name() = $tmp-word-tag or local-name() = $tmp-sentence-tag">
  	<!-- The node is ignored. This shouldn't happen though, because the -->
  	<!-- sentences have been properly distributed by the previous -->
  	<!-- script. -->
  	<xsl:apply-templates select="node()"/>
      </xsl:when>
      <xsl:otherwise>
  	<xsl:copy copy-namespaces="no">
  	  <xsl:call-template name="copy-namespaces"/>
  	  <xsl:apply-templates select="@*|node()"/>
  	</xsl:copy>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!--======================================================== -->
  <!-- INSIDE THE SENTENCES (ONCE THEY HAVE BEEN ADDED)        -->
  <!--======================================================== -->

  <xsl:template match="*[local-name() = $tmp-sentence-tag]" mode="inside-sentence" priority="2">
    <xsl:param name="parent-name"/>
    <!-- Ignore the node: since we are already inside a sentence,
         it means that a parent node has been recycled to contain the
         current sentence. -->
    <xsl:apply-templates select="node()" mode="inside-sentence">
      <xsl:with-param name="parent-name" select="$parent-name"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:variable name="ok-parent-list" select="concat(',', $can-contain-words, ',', $output-sentence-tag, ',')" />
  <xsl:template match="*[local-name() = $tmp-word-tag]" mode="inside-sentence" priority="2">
    <xsl:param name="parent-name"/>
    <xsl:choose>
      <xsl:when test="contains($ok-parent-list, concat(',', $parent-name, ','))">
	<xsl:element name="{$output-word-tag}" namespace="{$output-ns}">
	  <xsl:if test="$word-attr != ''">
	    <xsl:attribute name="{$word-attr}">
	      <xsl:value-of select="$word-attr-val"/>
	    </xsl:attribute>
	  </xsl:if>
	  <xsl:apply-templates select="node()" mode="inside-sentence">
	    <xsl:with-param name="parent-name" select="local-name()"/>
	  </xsl:apply-templates>
	</xsl:element>
      </xsl:when>
      <xsl:otherwise>
	<!-- The word is ignored. -->
	<xsl:apply-templates select="node()" mode="inside-sentence">
	  <xsl:with-param name="parent-name" select="local-name()"/>
	</xsl:apply-templates>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="node()" mode="inside-sentence" priority="1">
    <xsl:copy copy-namespaces="no">
      <xsl:call-template name="copy-namespaces"/>
      <xsl:copy-of select="@*"/>
      <xsl:apply-templates select="node()" mode="inside-sentence">
	<xsl:with-param name="parent-name" select="local-name()"/>
      </xsl:apply-templates>
    </xsl:copy>
  </xsl:template>

  <!-- UTILS -->
  <xsl:template name="copy-namespaces">
    <xsl:for-each select="namespace::* except namespace::tmp">
      <xsl:namespace name="{name(.)}" select="string(.)"/>
    </xsl:for-each>
  </xsl:template>

</xsl:stylesheet>

