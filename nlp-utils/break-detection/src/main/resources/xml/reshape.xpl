<p:declare-step type="px:reshape"
		version="1.0" xmlns:p="http://www.w3.org/ns/xproc"
		xmlns:px="http://www.daisy.org/ns/pipeline/xproc"
		xmlns:cx="http://xmlcalabash.com/ns/extensions"
		xmlns:tmp="http://www.daisy.org/ns/pipeline/tmp"
		exclude-inline-prefixes="#all">

  <p:import href="http://xmlcalabash.com/extension/steps/library-1.0.xpl"/>

  <p:option name="can-contain-sentences" required="true"/>
  <p:option name="special-sentences" required="false" select="''"/>
  <p:option name="output-word-tag" required="true"/>
  <p:option name="output-sentence-tag" required="true"/>
  <p:option name="word-attr" required="false" select="''"/>
  <p:option name="word-attr-val" required="false" select="''"/>
  <p:option name="output-ns" required="true"/>
  <p:option name="split-skippable" required="false" select="'false'"/>
  <p:option name="skippable-tags" required="false" select="''"/>
  <p:option name="output-subsentence-tag" required="true"/>
  <p:option name="tmp-ns" select="'http://www.daisy.org/ns/pipeline/tmp'"/>
  <p:option name="tmp-word-tag" select="'ww'"/>
  <p:option name="tmp-sentence-tag" select="'ss'"/>

  <p:input port="source" primary="true"/>
  <p:output port="result" primary="true"/>
  <p:output port="sentence-ids">
    <p:pipe port="secondary" step="create-valid"/>
  </p:output>

  <!-- Distribute some sentences to prevent them from having parents
       not compliant with the format. -->
  <p:xslt name="distribute">
    <p:with-param name="can-contain-sentences" select="$can-contain-sentences"/>
    <p:with-param name="tmp-word-tag" select="$tmp-word-tag"/>
    <p:with-param name="tmp-sentence-tag" select="$tmp-sentence-tag"/>
    <p:with-param name="tmp-ns" select="$tmp-ns"/>
    <p:input port="stylesheet">
      <p:document href="distribute-sentences.xsl"/>
    </p:input>
  </p:xslt>
  <cx:message message="Sentences distributed."/>

  <!-- Create the actual sentence/word elements. -->
  <p:xslt name="create-valid">
    <p:with-param name="can-contain-words" select="$can-contain-sentences"/>
    <p:with-param name="special-sentences" select="$special-sentences"/>
    <p:with-param name="tmp-word-tag" select="$tmp-word-tag"/>
    <p:with-param name="tmp-sentence-tag" select="$tmp-sentence-tag"/>
    <p:with-param name="output-word-tag" select="$output-word-tag"/>
    <p:with-param name="output-sentence-tag" select="$output-sentence-tag"/>
    <p:with-param name="word-attr" select="$word-attr"/>
    <p:with-param name="word-attr-val" select="$word-attr-val"/>
    <p:with-param name="output-ns" select="$output-ns"/>
    <p:input port="stylesheet">
      <p:document href="create-valid-breaks.xsl"/>
    </p:input>
  </p:xslt>
  <cx:message message="Format-compliant elements inserted."/>

  <!-- split the content around the skippable elements -->
  <p:choose name="split">
    <p:when test="$split-skippable = 'true'">
      <p:output port="result"/>
      <p:xslt>
	<p:input port="source">
	  <p:pipe port="result" step="create-valid"/>
	  <p:pipe port="secondary" step="create-valid"/> <!-- sentence ids -->
	</p:input>
	<p:with-param name="can-contain-subsentences" select="concat($can-contain-sentences, ',', $output-sentence-tag)"/>
	<p:with-param name="output-ns" select="$output-ns"/>
	<p:with-param name="skippable-tags" select="$skippable-tags"/>
	<p:with-param name="output-subsentence-tag" select="$output-subsentence-tag"/>
	<p:input port="stylesheet">
	  <p:document href="split-around-skippable.xsl"/>
	</p:input>
      </p:xslt>
      <cx:message message="Content split around the skippable elements."/>
    </p:when>
    <p:otherwise>
      <p:output port="result"/>
      <p:identity/>
    </p:otherwise>
  </p:choose>

</p:declare-step>