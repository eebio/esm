# Technical specification for Biological Data Transducer

## 1. Overview

This document defines the design specification for the biological data transducer program. This sets up not only limits in scope but also clear goals this project aims to hit. Furthermore, this acts as a method for assessing the success of the implementation. This spec was created as part of the EEBio project strand P2 focusing on the implementation and standardisation of synthetic biology software tools.

### 1.1 Purpose

- Standardise the parsing and storage of biological data taken from physical methods. 
- Current methods are purpose built per physical measurement device (e.g. plate reader, flow cytometer, sequencer, etc. ) with little standardisation. This leads to variation in not only reporting, but also analysis methods. 
  - This hinders the ability to wrote and standardise measurements taken from measurement devices. 
- Current solutions seek to only parse data to a machine readable CSV (see Parsely), with no standardisation steps. Furthermore, this is only for plate readers. 
- A program that could standardise the intermediate form of data coming off of measurement devices into a single format would aid in the development of tools to process and work with biological data. This would speed up development time in the laboratory by removing certain data transduction steps. 
- The product should capture key information about the machine used and experimental conditions.

### 1.2 Scope

- The proposed project's scope will be limited to the transduction of data to a standardised format. 
- This includes the calibration of output and some processing of output data.
- The produced program will allow for user defined calculations, where these follow a simple formula. 
- This project will aim to produce a standardised intermediate representation of biological data in a JSON format. 
- The aim is for the written program to be able to handle most forms of fluorescence data. 
- Some other formats, like sequencing and qPCR data may be considered if applicable. 
- This project does not seek to perform or produce publication ready graphs nor any calculations of part performance.
- This project will primarily aim to process data that comes from microplates.

### 1.3 Assumptions

- Users of the product do not have much if any technical computational experience, hence a need for a simple interface. 
- The product will need to be run without access to the internet.
- The machines running this product will range from low powered laptops to high performance computing clusters. 
- The product will form part of a pipeline of tools, as such the data outputted is an intermediate format.
- Many different operating systems (OSs) will be need to be supported. 
- The program will not need graphical user interface (GUI) and will instead use a command line interface (CLI)

### 1.4 Dependencies

- Other than being written in the Julia programming language and being compiled for multiple OSs, there are no other dependencies for this product.

## 2. Requirements

### 2.1 Functional Requirements

- Transduction of course biological data direct from a measurement device to a usable intermediate format. 
- Processing and calibration of output data. 
- Logging and parsing of experimental conditions. 
- Standardise the output data into one format. 

### 2.2 Non-Functional Requirements

- This product should be generalisable to most forms of biological data, within the previously described scope. 
- This product should be able to function as a stand alone tool, as well as part of a pipeline of tools.
- There are no major security problems envisaged stemming from this product. 
- This product should function on any machine from low powered computers to high performance clusters. 
- The response time of this product will depend on the data that inputted. 
- Maximum load will likely be determined by the users device capabilities.
- This product will not be constantly running, however uptime is difficult to predict as this purely hinges on the input data types. 

### 2.3 User Stories

**User case:** Plate reader
**Actions:** 

- Produces absorbance, fluorescence intensity, time resolved fluorescence, luminescence, polarization and light scattering data.
- Takes spectral, endpoint and time series readings. 
- Readings can be spread over multiple microplates and days. 
- Mircoplates range from 96 - 1536 wells in size. 
- Liquid volume can vary pending experiment type. 
- Experiment may not used a dissolved solute (e.g. plant leaf cuttings)
- Reads may be taken from top or bottom sensors for certain data types.
- Filters or monochrometers may be used to produce data.
- Samples may be agitated between reads.
- The read chamber may be heated to a specific temperature during read (temperature data reported).
- A lid or plastic film may be in place during reads. 
- Many different media used. 
- Multiple blanking solutions needed to adjust for autofluorescence.
- Reads taken sequentially at a time point, time can vary between first and last wells. 
- Calibrants can be run for some measurement types (e.g. RPU standard).

**User goals:**

- Produce normalised data that follows replicates across a time series, spectra or at specific time point. 
- Identify specific microplate wells with specific samples.
- Produce publication level graphs for figures. 

**User case:** Flow cytometer
**Actions:**

- Produces data on fluorescence intensity, scatter and other metrics for a single cells within a population of cells. 
- 10000 samples a second can be taken. 
- Cell sorting.
- Time Lapse and kinetic readings. 
- Rare cell detection.
- Structural and Morphological difference detection.

**User goals:**

- Produce standardised and normalised data
- Produce a human readable format of the FCS file.
- Calibrate the readings based on known calibrants.
- Isolate signals from different channels used. 
- Analyse scatter of both forward and side scatter. 

qPCR is not described here but may be added later in the project.

### 2.4 Use Cases

#### Use case 1: Plate Readers

- **Measurements taken**:
  - Absorbance 
  - Fluorescence intensity 
  - Time resolved fluorescence 
  - Luminescence 
  - Polarization 
  - Light scattering data
  - Temperature
- **Input files:**
  - CSV
  - TSV
  - XLSX
- **Output file:**
  - JSON
- **Metadata to be collected:** 
  - Instrument Type
  - Instrument Name
  - Filters/Monochromaters per reading
    - Wavelength 
      - Excitation
      - Emission 
    - Band width
      - Excitation
      - Emission 
    - Filter Brand
      - Excitation 
      - Emission 
    - Gain
      - Absorbance
      - Excitation
      - Emission 
    - Read location
      - Absorbance
      - Emission 
    - Read height
      - Absorbance
      - Emission 
    - Integration time/Resolution
  - Date(s) and time(s)
  - Person Conducting the experiment
  - Experiment type (Spectra, time point or time course)
  - Number of Plates
  - Number of different measurments being taken (Absorbance, Fluorescence 1, Florescence 2, etc.)
  - Plate type (Number of wells)
  - Sample type
  - Cover type
  - Index
  - Chamber temperature
  - Data samples:
    - Names
    - Well
    - Media
    - Antibiotics
    - Inducers
    - Volume
    - Read offset
    - Description
  - Calibrants:
    - Names
    - Well
    - Media
    - Antibiotic(s)
    - Inducer
    - Volume
    - Read offset
    - Description
  - Blanks:
    - Names
    - Well
    - Media
    - Antibiotic(s)
    - Inducer
    - Volume
    - Read offset
    - Description
  - Controls:
    - Names
    - Well
    - Media
    - Antibiotic(s)
    - Inducer
    - Volume
    - Read offset
    - Description
- **Standard data processing**
  - Absorbance:
    - Subtract blank well average from data wells.
  - Fluorescence intensity and other methods:
    - Subtract media blank autofluorescence.
    - Normalise to the adjusted OD.
    - Subtract blank spectra from observed spectra

**Use case 2: Flow cytometers**

- **Measurements taken:** 
  - Forward angle scatter
  - Side angle scatter
  - Florescence intensity - multiple
- **Input files:** 
  - FCS - multiple (1 per well)
- **Output file:**
  - JSON
- **Metadata to be collected:** 
  - Instrument Type
  - Instrument Name
  - Filters
    - Wavelength 
      - Excitation
      - Emission 
    - Band width
      - Excitation
      - Emission 
    - Filter Brand
      - Excitation 
      - Emission 
  - Date(s) and time(s)
  - Person conducting the experiment
  - Number of Plates
  - Number of different measurments being taken (Absorbance, Fluorescence 1, Florescence 2, etc.)
  - Plate type (Number of wells)
  - Sample type
  - Data samples:
    - Names
    - Well
    - Media
    - Antibiotics
    - Inducers
    - Volume
    - Read offset
    - Description
    - Number of counts
  - Calibrants:
    - Names
    - Well
    - Media
    - Antibiotic(s)
    - Inducer
    - Volume
    - Read offset
    - Description
    - Number of counts
  - Blanks:
    - Names
    - Well
    - Media
    - Antibiotic(s)
    - Inducer
    - Volume
    - Read offset
    - Description
    - Number of counts
  - Controls:
    - Names
    - Well
    - Media
    - Antibiotic(s)
    - Inducer
    - Volume
    - Read offset
    - Description
    - Number of counts
- **Standard data processing:**
  - Gating cell counts. 
  - Calibrating using beads.

## 3. Design

### 3.1 Architecture Overview

- There is no specific architecture associated with this program, given it is a standalone program (hence no architecture diagram).
- As it might become a functional component in a pipeline, considerations must be made to ensure that the data outputted is machine readable and space efficient. 
  - For this program the chosen output file is of JSON format which is readily readable by most modern programming languages. 
  - This also allows for scalability as it is easy to read and breakdown JSON files and it is a standard data format. 
- The metadata that is taken in from the metadata document can easily be expanded. This means that other forms of data acquisition (e.g. qPCR etc) can be added in the future. 
- The program should throw an error if a key metadata field is either not populated. 
  - Any non-standard fields should default to blank.

### 3.2 Data Models

- This will follow a hierarchical model. 
- All plate reader fields not used in the flow cytometer data will be left blank and vice versa.
- All indexing will be per plate that is present to allow for a full audit trail of experimenter, machine and date.
  - This also simplifies the iteration process and allows scalability of the final format.

**Broad level JSON organisation:**
- Broad metadata:
- Well IDs and contents
- Transformations
- Output Data

**Broad metadata organisation:**
- Captures all information associated with the machine and experiment outside of the individual wells used. 
- Format: 
  - Instrument Type (Plate reader or Flow cytometer) (String)
  - Instrument Name (String)
  - Filters/Monochromaters/Lasers per channel (Dictionary)
    - Optics (iterates via optics_0x):
      - Wavelength 
        - Excitation (Float)
        - Emission (Float)
      - Band width
        - Excitation (Float)
        - Emission (Float)
      - Filter Brand
        - Excitation (String)
        - Emission (String)
      - Gain (Float)
      - Read location (String)
      - Read height (Float)
      - Total read time (Float)
      - Per well read time (Float)
      - Integration time/Resolution (Float)
  - Date(s) and time(s) (Dictionary{String} format: YYYY-MM-DD-TT:TT)
  - Person Conducting the experiment (Dictionary{String})
  - Experiment type (Spectra, time point or time course) (String)
  - Number of Plates (Integer)
  - Number of different measurments being taken (Absorbance, Fluorescence 1, Florescence 2, etc.) (Integer)
  - Plate type (Number of wells) (Integer)
  - Sample type (String)
  - Cover type (String)
  - Index (Array{Float})
  - Chamber temperature (Dictionary{Array{Float}})

**Well level organisation:**
- The per group data structure will be: 
- Group Name
  - Media (String)
  - Antibiotics (Array{String})
  - Inducers (Array{String})
  - Description (String)
  - Wells (Dictionary)
    - Plate (iterates in form plate_0x - Array{String})

**Output_data organisation:**
- This is the transformed data outputted by the program. 
- Structure: 
  - Group name (String)
    - Plate (iterated as plate_0x)
      - Measurement (e.g. OD, Fluorescence/OD)
        - Wells (Array{String})



### 3.3 API Design
If your system includes an API, describe the endpoints, request/response formats, authentication mechanisms, and error handling strategies.

### 3.4 UI/UX Design
 
- This will be a CLI and as such will have no user GUI. 
- The CLI should purely be as follows: 
```command metadata.JSON```
```command metadata.JSON```

## 4. Implementation

### 4.1 Tech Stack
List the technologies, programming languages, frameworks, and tools that will be used in the project. Justify why each was chosen, considering factors like performance, compatibility, and ease of use.

### 4.2 Code Structure
Provide an overview of the code structure, including how files and directories will be organized. This could include directory structures, naming conventions, and patterns.

### 4.3 Libraries and Frameworks
Identify any external libraries or frameworks that will be used and explain how they fit into the project. Include versions and any licensing considerations.

### 4.4 Development Workflow
Explain the development process, including:
- **Version control practices** (e.g., branching strategy)
- **Testing and quality assurance** (e.g., unit tests, code reviews)
- **Deployment pipeline** (e.g., CI/CD setup)

## 5. Testing

### 5.1 Test Strategy
Describe the overall testing strategy for the project. Will it use unit tests, integration tests, end-to-end tests, etc.? 

### 5.2 Test Cases
Provide examples of specific test cases or scenarios that need to be validated. Include expected inputs and outputs.

### 5.3 Testing Tools
Identify the testing tools and frameworks that will be used, such as Jest, Mocha, Selenium, etc.

## 6. Security

### 6.1 Threat Model
Identify potential security threats and vulnerabilities in the system, such as injection attacks, data breaches, and unauthorized access.

### 6.2 Authentication and Authorization
Describe the approach for authenticating and authorizing users. Include methods such as OAuth, JWT, and role-based access control (RBAC).

### 6.3 Data Protection
Explain how sensitive data will be protected both in transit and at rest. Consider encryption standards, secure storage, and data masking.

## 7. Performance and Scalability

### 7.1 Performance Requirements
Define the expected performance metrics, such as response times, throughput, or concurrency limits.

### 7.2 Scalability Strategy
Explain how the system will scale as the number of users or data volume grows. Include horizontal vs. vertical scaling, load balancing, and database sharding, if applicable.

### 7.3 Stress Testing
Describe the approach for stress testing the system to ensure it performs well under extreme conditions.

## 8. Deployment and Operations

### 8.1 Deployment Strategy
Describe the deployment process, including any environments (development, staging, production) and tools used (e.g., Kubernetes, Docker, cloud services).

### 8.2 Rollback Plan
Provide a plan for rolling back deployments in case of issues. This includes backup strategies and versioning control.

### 8.3 Monitoring and Maintenance
Outline the monitoring tools, logging practices, and metrics to track system health and performance. Describe how maintenance tasks will be handled.

## 9. Timeline

### 9.1 Milestones
List key project milestones with estimated dates for each stage (e.g., design completion, beta release, final release).

### 9.2 Deliverables
Define the deliverables associated with each milestone. This could include code artifacts, documentation, or user manuals.

## 10. Conclusion
Summarize the key points of the specification, reiterating the importance of the project and how the outlined solution meets the needs of the users and stakeholders.

---

*Author(s):* Micha Y T Claydon

*Version:* 0.1

*Creation Date:* 11/11/2024

*Last update:* 13/11/2024

*Maintainer:* Micha Y T Claydon
