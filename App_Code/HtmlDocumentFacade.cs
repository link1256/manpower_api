using System;
using System.Collections.Generic;
using System.Text;
using System.Xml;

namespace Supergeo.Utilities
{
    public class HtmlDocumentFacade
    {
        protected XmlElement body;
        protected XmlDocument document;
        protected XmlElement head;
        protected XmlElement html;

        //Dictionary from tag name, to map linking known styles and css class names
        private Dictionary<string, Dictionary<string, string>> stylesheet = new Dictionary<string, Dictionary<string, string>>();
        private XmlElement stylesheetElement;
        private Dictionary<string, string> exactStylesheet = new Dictionary<string, string>();

        protected XmlElement title;
        protected XmlText titleText;

        public HtmlDocumentFacade(XmlDocument document)
        {
            this.document = document;

            html = document.CreateElement("html");
            html.SetAttribute("lang", "zh-Hant-TW");
            document.AppendChild(html);

            body = document.CreateElement("body");
            head = document.CreateElement("head");
            stylesheetElement = document.CreateElement("style");
            stylesheetElement.SetAttribute("type", "text/css");

            html.AppendChild(head);
            html.AppendChild(body);
            head.AppendChild(stylesheetElement);
            AddCharset();
            AddStyleClass(body, "b", "white-space-collapsing:preserve;");
        }
        // add by Antony
        // 不写charset，部分浏览器可能无法正确显示
        public void AddCharset()
        {
            XmlElement meta = document.CreateElement("meta");
            meta.SetAttribute("http-equiv", "Content-Type");
            meta.SetAttribute("content", "text/html; charset=UTF-8");
            head.AppendChild(meta);
        }
        public void AddAuthor(string value)
        {
            AddMeta("author", value);
        }
        public void AddDescription(string value)
        {
            AddMeta("description", value);
        }

        public void AddKeywords(string value)
        {
            AddMeta("keywords", value);
        }

        public void AddMeta(string name, string value)
        {
            XmlElement meta = document.CreateElement("meta");
            meta.SetAttribute("name", name);
            meta.SetAttribute("content", value);
            head.AppendChild(meta);
        }

        public void AddStyleClass(XmlElement element, string classNamePrefix, string style)
        {
            string exising = element.GetAttribute("class");
            string addition = GetOrCreateCssClass(element.Name, classNamePrefix, style);
            string newClassValue = string.IsNullOrEmpty(exising) ? addition
                    : (exising + " " + addition);
            element.GetAttribute("class", newClassValue);
        }

        public XmlElement CreateBlock()
        {
            return document.CreateElement("div");
        }

        public XmlElement CreateBookmark(string name)
        {
            XmlElement basicLink = document.CreateElement("a");
            basicLink.SetAttribute("name", name);
            return basicLink;
        }

        public XmlElement CreateHeader1()
        {
            return document.CreateElement("h1");
        }

        public XmlElement CreateHeader2()
        {
            return document.CreateElement("h2");
        }

        public XmlElement CreateHyperlink(string internalDestination)
        {
            XmlElement basicLink = document.CreateElement("a");
            basicLink.SetAttribute("href", internalDestination);
            return basicLink;
        }

        public XmlElement CreateImage(string src)
        {
            XmlElement result = document.CreateElement("img");
            result.SetAttribute("src", src);
            return result;
        }

        public XmlElement CreateLineBreak()
        {
            return document.CreateElement("br");
        }

        public XmlElement CreateListItem()
        {
            return document.CreateElement("li");
        }

        public XmlElement CreateParagraph()
        {
            return document.CreateElement("p");
        }

        public XmlElement CreateTable()
        {
            return document.CreateElement("table");
        }

        public XmlElement CreateTableBody()
        {
            return document.CreateElement("tbody");
        }

        public XmlElement CreateTableCell()
        {
            return document.CreateElement("td");
        }

        public XmlElement CreateTableColumn()
        {
            return document.CreateElement("col");
        }

        public XmlElement CreateTableColumnGroup()
        {
            return document.CreateElement("colgroup");
        }

        public XmlElement CreateTableHeader()
        {
            return document.CreateElement("thead");
        }

        public XmlElement CreateTableHeaderCell()
        {
            return document.CreateElement("th");
        }

        public XmlElement CreateTableRow()
        {
            return document.CreateElement("tr");
        }

        public XmlText CreateText(string data)
        {
            return document.CreateTextNode(data);
        }

        public XmlElement CreateDiv()
        {
            return document.CreateElement("div");
        }

        public XmlElement CreateUnorderedList()
        {
            return document.CreateElement("ul");
        }
        public XmlElement Body
        {
            get { return body; }
        }
        public XmlDocument Document
        {
            get { return document; }
        }
        public XmlElement Head
        {
            get { return head; }
        }

        public string CreateOrReplaceExactCssClass(string tagName, string style)
        {
            String cssClass = tagName;
            if (exactStylesheet.ContainsKey(tagName))
            {
                exactStylesheet[tagName] = style;
            }
            else
            {
                exactStylesheet.Add(tagName, style);
            }
            return cssClass;
        }

        public string GetOrCreateCssClass(string tagName, string classNamePrefix, string style)
        {
            if (!stylesheet.ContainsKey(tagName))
                stylesheet.Add(tagName, new Dictionary<string, string>(1));

            Dictionary<string, string> styleToClassName = stylesheet[tagName];

            string knownClass;
            if (styleToClassName.ContainsKey(style))
            {
                knownClass = styleToClassName[style];
                return knownClass;
            }
            string newClassName = classNamePrefix + (styleToClassName.Count + 1);
            styleToClassName.Add(style, newClassName);
            return newClassName;
        }

        public string GetCssContent(string tagName, string className)
        {
            String cssClass = "";
            if (stylesheet.ContainsKey(tagName))
            {
                Dictionary<string, string> styleToClassName = stylesheet[tagName];
                if (styleToClassName != null)
                {
                    String cssKey = null;
                    foreach (String key in styleToClassName.Keys)
                    {
                        if (String.Compare(className, styleToClassName[key], true) == 0)
                        {
                            cssKey = key;
                            break;
                        }
                    }
                    if (cssKey != null)
                    {
                        //styleToClassName.Remove(cssKey);
                        cssClass = cssKey;
                    }
                }
            }
            return cssClass;
        }

        public string RemoveCssClass(string tagName, string className)
        {
            String cssClass = "";
            if (stylesheet.ContainsKey(tagName))
            {
                Dictionary<string, string> styleToClassName = stylesheet[tagName];
                if (styleToClassName != null)
                {
                    String cssKey = null;
                    foreach (String key in styleToClassName.Keys)
                    {
                        if (String.Compare(className, styleToClassName[key], true) == 0)
                        {
                            cssKey = key;
                            break;
                        }
                    }
                    if (cssKey != null)
                    {
                        styleToClassName.Remove(cssKey);
                        if (styleToClassName.Count == 0)
                        {
                            // 沒資料, 清空
                            stylesheet.Remove(tagName);
                        }
                        cssClass = cssKey;
                    }
                }
            }
            return cssClass;
        }

        public string Title
        {
            get
            {
                if (title == null)
                    return null;
                return titleText.InnerText;
            }
            set
            {
                if (string.IsNullOrEmpty(value) && this.title != null)
                {
                    this.head.RemoveChild(this.title);
                    this.title = null;
                    this.titleText = null;
                }

                if (this.title == null)
                {
                    this.title = document.CreateElement("title");
                    this.titleText = document.CreateTextNode(value);
                    this.title.AppendChild(this.titleText);
                    this.head.AppendChild(title);
                }

                this.titleText.InnerText = value;
            }
        }

        /*

        public string getTitle()
        {
            if (title == null)
                return null;

            //return titleText.getTextContent();
            return titleText.InnerText;
        }

        public void setTitle(string titleText)
        {
            if (string.IsNullOrEmpty(titleText) && this.title != null)
            {
                //this.head.removeChild(this.title);
                this.title = null;
                this.titleText = null;
            }

            if (this.title == null)
            {
                this.title = document.CreateElement("title");
                this.titleText = document.CreateTextNode(titleText);
                this.title.AppendChild(this.titleText);
                this.head.AppendChild(title);
            }

            //this.titleText.setData(titleText);
            this.titleText.InnerXml = titleText;
        }
         */

        public void UpdateStylesheet()
        {
            StringBuilder stringBuilder = new StringBuilder();
            stringBuilder.Append("\n");
            foreach (KeyValuePair<string, Dictionary<string, string>> kvTag in stylesheet)
            {
                string tagName = kvTag.Key;
                foreach (KeyValuePair<string, string> kvStyle in kvTag.Value)
                {
                    string style = kvStyle.Key;
                    string className = kvStyle.Value;

                    stringBuilder.Append(tagName + "." + className + "{" + style + "}\n");
                }
            }
            foreach (String strKey in exactStylesheet.Keys)
            {
                stringBuilder.Append("." + strKey + "{" + exactStylesheet[strKey] + "}\n");
            }
            //stylesheetElement.setTextContent( stringBuilder.toString() );
            stylesheetElement.InnerText = stringBuilder.ToString();
        }
    }
}
