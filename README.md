# Jupiter Simulationsumgebung
In this repository can be found the code for the Jupiter Simulationsumgebung project.
The task and an instruction how the task was solved can be found under this link [](https://dud-wiki.inf.tu-dresden.de/tiki-index.php?page=Jupiter---Simulationsumgebung)

This repository is structured into several folders:

In the "Model Generation Script" folder is every single script listed, which is needed to generate a Smartnet Model for GridlabD
For Example there is a script to produce player files used by gridlabd from the london smartmeter dataset.
Further Explanations can be found in the Readme of the folder Model Generation Script.

In the folder European Model is a big gridlabd model which simulates a european smartgrid. It uses several real world player from the london smartmeter dataset.
The player are created by the Script from the "Model Generation Script" folder.
If gridlabd is installed the model may be run with the command "gridlabd gridLAB_D_Model.glm --profile" in the terminal.

In the "Test Models" folder is just a small model called haus.glm for test purposes.

In the "Berlin Gridlabd Model " folder is a Model used for Analysis. It is created in a early process of the project. 

A refactored and more lightweight version of the Berlin Gridlabd Model can be found in the "Test Models/Generated Model" folder.
That's why it is recommended to use the Folder "Generate Model" to create a new project for analysis.

